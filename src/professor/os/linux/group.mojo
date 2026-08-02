from std.sys._libc_errno import get_errno
from std.ffi import c_int, c_size_t, c_ulong

from ._file import _FileHandle
from ._sys import (
    PERF_IOC_FLAG_GROUP,
    perf_event_open,
    perf_event_read,
    perf_event_enable,
    perf_event_disable,
    perf_event_reset,
    perf_event_id,
)
from .config import (
    Config,
    CountMode,
    Virtualization,
    Flag,
    CpuId,
    ProcessId
)
from ._event import PerfEvent


struct GroupBuilder(Movable):

    var _cpu: CpuId
    """ID of the CPU to monitor."""

    var _process: ProcessId
    """ID of the process to monitor."""

    var _flag: Flag
    """Flags when opening the perf event."""

    var _config: Config
    """Configuration prototype."""

    def __init__(
        out self,
        read_format: UInt64,
        *,
        cpu: CpuId = CpuId.Any,
        process: ProcessId = ProcessId.Calling,
        flag: Flag = Flag.CloseOnExec,
        mode: CountMode = CountMode.Userspace,
        virtualization: Virtualization = Virtualization.Host,
    ):
        self._cpu = cpu
        self._process = process
        self._flag = flag

        self._config = Config()
        self._config.read_format = read_format

        self._config.set_disabled(True)

        self._config.set_exclude_user(not mode.includes(CountMode.Userspace))
        self._config.set_exclude_kernel(not mode.includes(CountMode.Kernel))
        self._config.set_exclude_hv(not mode.includes(CountMode.Hypervisor))

        self._config.set_exclude_idle(False)

        self._config.set_exclude_host(
            not virtualization.includes(Virtualization.Host)
        )
        self._config.set_exclude_guest(
            not virtualization.includes(Virtualization.Guest)
        )

    def build(mut self, events: List[PerfEvent]) raises -> Group:
        """Open `events` as one kernel-scheduled performance event group.

        The first requested event becomes the group leader. Every remaining
        event is added as a member, and every returned file descriptor is
        owned by the resulting `Group`.
        """
        if len(events) == 0:
            raise Error("events cannot be empty")

        var files = List[_FileHandle](capacity=len(events))
        var ids = List[UInt64](capacity=len(events))

        for i in range(len(events)):
            var event = events[i]

            var config = self._config.copy()
            config.type_ = event.type()
            config.config = event.config()

            var group_fd = c_int(-1)
            if i > 0:
                config.set_disabled(False)
                group_fd = files[0]._get_raw_fd()

            var fd = perf_event_open(
                UnsafePointer(to=config),
                c_int(self.process.value),
                c_int(self.cpu.value),
                group_fd,
                c_ulong(Flag.CloseOnExec.value),
            )
            if fd < 0:
                var err = get_errno()
                raise Error(t"perf_event_open({event.name()}) failed: {err}")

            var file = _FileHandle(unsafe_fd=fd)
            var event_id: UInt64 = 0
            if (
                perf_event_id(file._get_raw_fd(), UnsafePointer(to=event_id))
                != 0
            ):
                var err = get_errno()
                raise Error(
                    t"failed to get performance event id for "
                    t"{event.name()}: {err}"
                )

            files.append(file^)
            ids.append(event_id)

        return Group(files^, ids^)


struct Group(Movable):
    """An owned group of simultaneously scheduled counting events.

    The first requested event is the kernel group leader. `Group` owns the
    leader and every member file descriptor, so dropping the group closes the
    entire group. Enable, disable, and reset operations apply to every event.

    A hardware group can run only when all of its events fit on the PMU at the
    same time. Callers should inspect the enabled and running times returned by
    a group read to detect a group that could not be scheduled.
    """

    var _files: List[_FileHandle]
    """Owned event files in group order, with the leader first."""

    var _ids: List[UInt64]
    """Kernel-assigned event IDs in the same order as `_files`."""

    var _event_count: Int
    """The number of requested events in the group."""

    def __init__(
        out self,
        var files: List[_FileHandle],
        var ids: List[UInt64],
    ):
        debug_assert(len(files) > 0, "a group must contain a leader")
        debug_assert(len(files) == len(ids), "event files and IDs must match")
        self._event_count = len(files)
        self._files = files^
        self._ids = ids^

    @always_inline
    def _leader_fd(self) -> c_int:
        return self._files[0]._get_raw_fd()

    def id(self) -> UInt64:
        """Returns the unique id of the leader event assigned by the kernel.

        Returns:
            The leader event's unique id.
        """
        return self._ids[0]

    def event_count(self) -> Int:
        """Return the number of requested events in the group."""
        return self._event_count

    def enable(mut self) raises:
        """Enable every event in this group.

        Existing counts are preserved; new events add to them until the group
        is disabled. Call `reset()` separately to clear the counts.
        """
        if perf_event_enable(self._leader_fd(), PERF_IOC_FLAG_GROUP) != 0:
            var err = get_errno()
            raise Error(t"failed to enable event group: {err}")

    def disable(mut self) raises:
        """Disable every event in this group without changing its counts."""
        if perf_event_disable(self._leader_fd(), PERF_IOC_FLAG_GROUP) != 0:
            var err = get_errno()
            raise Error(t"failed to disable event group: {err}")

    def reset(mut self) raises:
        """Reset every event count without resetting multiplexing times."""
        if perf_event_reset(self._leader_fd(), PERF_IOC_FLAG_GROUP) != 0:
            var err = get_errno()
            raise Error(t"failed to reset event group: {err}")

    def read[
        origin: MutOrigin
    ](self, buffer: Span[UInt64, origin]) raises -> Int:
        """Read counting payload into a span.

        Args:
            buffer: The mutable Span to read data into.

        Returns:
            The total amount of data that was read in bytes.

        Raises:
            An error if this file handle is invalid, or if the file read
            returned a failure.
        """

        var fd = self._leader_fd()
        if fd < 0:
            raise Error("invalid file handle")

        var bytes_read = perf_event_read(
            fd, buffer.unsafe_ptr(), c_size_t(len(buffer))
        )

        if bytes_read < 0:
            var err = get_errno()
            raise Error("failed to read event group: " + String(err))

        return bytes_read
