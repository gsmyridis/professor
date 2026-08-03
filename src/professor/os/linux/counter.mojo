from std.ffi import c_int, c_size_t, c_ulong
from std.sys._libc_errno import get_errno
from std.sys.info import size_of

from .sys import (
    PERF_FORMAT_TOTAL_TIME_ENABLED,
    PERF_FORMAT_TOTAL_TIME_RUNNING,
    perf_event_open,
    perf_event_enable,
    perf_event_disable,
    perf_event_reset,
    perf_event_id,
    perf_event_read,
)
from .file import _FileHandle
from .event import PerfEvent
from .config import (
    Config,
    CounterConfig,
    CountMode,
    Virtualization,
    Flag,
    CpuId,
    ProcessId,
)
from .counts import Count

comptime NO_GROUP = -1


# ===------------------------------------------------------------------------===
# Counter
# ===------------------------------------------------------------------------===


struct Counter(Movable):
    """An independently controlled counter opened from a `CounterConfig`."""

    var _handle: _CounterHandle
    """The opened perf-event handle owned by this counter.

    When a `Counter` is dropped, its file is dropped and the kernel removes the
    corresponding event.
    """

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    def __init__(
        out self,
        counter_config: CounterConfig,
        *,
        cpu: CpuId = CpuId.Any,
        process: ProcessId = ProcessId.Calling,
        flag: Flag = Flag.CloseOnExec,
    ) raises:
        """Open a standalone counter with the requested target settings."""
        var config = Config()
        config.read_format = (
            PERF_FORMAT_TOTAL_TIME_ENABLED | PERF_FORMAT_TOTAL_TIME_RUNNING
        )

        var file = _open_event(
            counter_config,
            config^,
            cpu,
            process,
            flag,
            NO_GROUP,
            disabled=True,
        )
        self._handle = _CounterHandle(counter_config.event, file^)

    # ===--------------------------------------------------------------------===
    # Accessor methods
    # ===--------------------------------------------------------------------===

    def id(self) -> UInt64:
        """Returns the unique id assigned by the kernel.

        Returns:
            The counter's unique id.
        """
        return self._handle.id()

    def raw_fd(self) -> c_int:
        """Returns the raw file descriptor.

        Returns:
            The counter's file descriptor.
        """
        return self._handle.raw_fd()

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


# ===------------------------------------------------------------------------===
# Counter handle
# ===------------------------------------------------------------------------===


struct _CounterHandle(Movable):
    """Internal ownership of one opened perf event."""

    var _event: PerfEvent
    var _file: _FileHandle
    var _id: UInt64

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    def __init__(out self, event: PerfEvent, var file: _FileHandle) raises:
        self._event = event
        self._file = file^
        self._id = 0
        if (
            perf_event_id(self._file._get_raw_fd(), UnsafePointer(to=self._id))
            != 0
        ):
            var err = get_errno()
            raise Error(t"failed to get performance event id: {err}")

    def close(mut self) raises:
        self._file.close()

    # ===--------------------------------------------------------------------===
    # Accessor methods
    # ===--------------------------------------------------------------------===

    def id(self) -> UInt64:
        return self._id

    def raw_fd(self) -> c_int:
        return self._file._get_raw_fd()


# ===------------------------------------------------------------------------===
# Open event helper
# ===------------------------------------------------------------------------===


def _open_event(
    counter_config: CounterConfig,
    var config: Config,
    cpu: CpuId,
    process: ProcessId,
    flag: Flag,
    group_leader_fd: c_int,
    *,
    disabled: Bool,
) raises -> _FileHandle:
    var event = counter_config.event
    config.type_ = event.type()
    config.config = event.config()

    config.set_disabled(disabled)
    config.set_exclude_idle(counter_config.exclude_idle)

    config.set_exclude_user(
        not counter_config.mode.includes(CountMode.Userspace)
    )
    config.set_exclude_kernel(
        not counter_config.mode.includes(CountMode.Kernel)
    )
    config.set_exclude_hv(
        not counter_config.mode.includes(CountMode.Hypervisor)
    )

    config.set_exclude_host(
        not counter_config.virtualization.includes(Virtualization.Host)
    )
    config.set_exclude_guest(
        not counter_config.virtualization.includes(Virtualization.Guest)
    )

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
