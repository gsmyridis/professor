from std.ffi import c_int, c_size_t, c_ulong
from std.sys._libc_errno import get_errno
from std.sys.info import size_of

from ._sys import (
    PERF_FORMAT_TOTAL_TIME_ENABLED,
    PERF_FORMAT_TOTAL_TIME_RUNNING,
    perf_event_open,
    perf_event_enable,
    perf_event_disable,
    perf_event_reset,
    perf_event_id,
    perf_event_read,
)
from ._file import _FileHandle
from ._event import PerfEvent
from .config import Config, CountMode, Virtualization, Flag, CpuId, ProcessId
from .counts import Count

comptime NO_GROUP = -1


def _open_event(
    event: PerfEvent,
    var config: Config,
    cpu: CpuId,
    process: ProcessId,
    flag: Flag,
    mode: CountMode,
    virtualization: Virtualization,
    group_leader_fd: c_int,
) raises -> _FileHandle:
    config.type_ = event.type()
    config.config = event.config()

    config.set_disabled(True)
    config.set_exclude_idle(False)

    config.set_exclude_user(not mode.includes(CountMode.Userspace))
    config.set_exclude_kernel(not mode.includes(CountMode.Kernel))
    config.set_exclude_hv(not mode.includes(CountMode.Hypervisor))

    config.set_exclude_host(not virtualization.includes(Virtualization.Host))
    config.set_exclude_guest(not virtualization.includes(Virtualization.Guest))

    var fd = perf_event_open(
        UnsafePointer(to=config),
        c_int(process.value),
        c_int(cpu.value),
        group_leader_fd,
        c_ulong(flag.value),
    )
    if fd < 0:
        var err = get_errno()
        raise Error(t"perf_event_open({event.name()}) failed: {err}")

    return _FileHandle(unsafe_fd=fd)


struct Counter(Movable):
    # ===--------------------------------------------------------------------===
    # Fields
    # ===--------------------------------------------------------------------===

    var _event: PerfEvent
    """Performance event description."""

    var _file: _FileHandle
    """The perf-event file handle for this counter, returned by `perf_event_open`.

    When a `Counter` is dropped, this file is dropped, and the kernel
    removes the counter from any group it belongs to.
    """

    var _id: UInt64
    """The unique id assigned to this counter by the kernel."""

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    def __init__(
        out self,
        event: PerfEvent,
        *,
        cpu: CpuId = CpuId.Any,
        process: ProcessId = ProcessId.Calling,
        flag: Flag = Flag.CloseOnExec,
        mode: CountMode = CountMode.Userspace,
        virtualization: Virtualization = Virtualization.Host,
    ) raises:
        var config = Config()
        config.read_format = (
            PERF_FORMAT_TOTAL_TIME_ENABLED | PERF_FORMAT_TOTAL_TIME_RUNNING
        )

        var file = _open_event(
            event, config^, cpu, process, flag, mode, virtualization, NO_GROUP
        )
        self = Self(event=event, unsafe_file=file^)

    def __init__(
        out self, *, event: PerfEvent, var unsafe_file: _FileHandle
    ) raises:
        """Initialises a `Counter` from the performance event's file handle."""
        self._event = event

        self._file = unsafe_file^
        self._id = 0
        if (
            perf_event_id(self._file._get_raw_fd(), UnsafePointer(to=self._id))
            != 0
        ):
            var err = get_errno()
            raise Error(t"failed to get performance event id: {err}")

    # ===--------------------------------------------------------------------===
    # Accessor methods
    # ===--------------------------------------------------------------------===

    def id(self) -> UInt64:
        """Returns the unique id assigned by the kernel.

        Returns:
            The counter's unique id.
        """
        return self._id

    def raw_fd(self) -> c_int:
        """Returns the raw file descriptor.

        Returns:
            The counter's fild descriptor.
        """
        return self._file._get_raw_fd()

    # ===--------------------------------------------------------------------===
    # Control methods
    # ===--------------------------------------------------------------------===

    def enable(mut self) raises:
        """Allow this `Counter` to begin counting its designated event.

        This does not affect whatever value the `Counter` had previously; new
        events add to the current count. To clear a `Counter`, use the
        `reset` method.

        Note that `Group` also has an `enable` method, which enables all
        its member `Counter`s as a single atomic operation.
        """
        if perf_event_enable(self.raw_fd()) != 0:
            var err = get_errno()
            raise Error(t"failed to enable counter: {err}")

    def disable(mut self) raises:
        """Make this `Counter` stop counting its designated event. Its count is
        unaffected.

        Note that `Group` also has a `disable` method, which disables all its
        member `Counter`s as a single atomic operation.
        """
        if perf_event_disable(self.raw_fd()) != 0:
            var err = get_errno()
            raise Error(t"failed to disable counter: {err}")

    def reset(mut self) raises:
        """Reset the value of this `Counter` to zero.

        Note that `Group` also has a `reset` method, which resets all its member
        `Counter`s as a single atomic operation.
        """
        if perf_event_reset(self.raw_fd()) != 0:
            var err = get_errno()
            raise Error(t"failed to reset counter: {err}")

    # ===--------------------------------------------------------------------===
    # Read
    # ===--------------------------------------------------------------------===

    def read(self) raises -> Count:
        """Read the counter value and multiplexing timing metadata."""
        var fd = self.raw_fd()
        if fd < 0:
            raise Error("invalid file handle")

        var buffer = InlineArray[UInt64, 3](fill=0)
        var bytes_read = perf_event_read(
            fd, buffer.unsafe_ptr(), c_size_t(len(buffer))
        )
        if bytes_read < 0:
            var err = get_errno()
            raise Error("failed to read counter: " + String(err))

        comptime expected_bytes = 3 * size_of[UInt64]()
        if Int(bytes_read) != expected_bytes:
            raise Error(
                t"invalid counter read size: expected {expected_bytes} bytes, "
                t"received {bytes_read}"
            )

        return Count(buffer[0], buffer[1], buffer[2])
