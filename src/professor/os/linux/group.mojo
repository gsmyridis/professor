from std.sys._libc_errno import get_errno
from std.ffi import c_int, c_size_t
from std.sys.info import size_of

from .counter import Counter, _open_event, NO_GROUP
from ._sys import (
    PERF_FORMAT_GROUP,
    PERF_FORMAT_ID,
    PERF_FORMAT_TOTAL_TIME_ENABLED,
    PERF_FORMAT_TOTAL_TIME_RUNNING,
    PERF_IOC_FLAG_GROUP,
    perf_event_read,
    perf_event_enable,
    perf_event_disable,
    perf_event_reset,
)
from .config import (
    Config,
    CountMode,
    Virtualization,
    Flag,
    CpuId,
    ProcessId,
)
from ._event import PerfEvent
from .counts import Counts


struct Group(Movable, Sized):
    """An owned group of simultaneously scheduled counting events.

    The first requested event is the kernel group leader. `Group` owns the
    leader and every member file descriptor, so dropping the group closes the
    entire group. Enable, disable, and reset operations apply to every event.

    A hardware group can run only when all of its events fit on the PMU at the
    same time. Callers should inspect the enabled and running times returned by
    a group read to detect a group that could not be scheduled.
    """

    # ===---------------------------------------------------------------------===
    # Method
    # ===---------------------------------------------------------------------===

    var _counters: List[Counter]
    """Owned counters in group order, with the leader first."""

    # ===---------------------------------------------------------------------===
    # Lifecycle methods
    # ===---------------------------------------------------------------------===

    def __init__(
        out self,
        events: List[PerfEvent],
        *,
        cpu: CpuId = CpuId.Any,
        process: ProcessId = ProcessId.Calling,
        flag: Flag = Flag.CloseOnExec,
        mode: CountMode = CountMode.Userspace,
        virtualization: Virtualization = Virtualization.Host,
    ) raises:
        if Flag.NoGroup in flag:
            raise Error("cannot set Flag.NoGroup for a group")

        if len(events) == 0:
            raise Error("events cannot be empty")

        var config_prototype = Config()
        config_prototype.read_format = (
            PERF_FORMAT_GROUP
            | PERF_FORMAT_ID
            | PERF_FORMAT_TOTAL_TIME_ENABLED
            | PERF_FORMAT_TOTAL_TIME_RUNNING
        )

        self._counters = List[Counter](capacity=len(events))

        for i, event in enumerate(events):
            var config = config_prototype.copy()

            var group_fd = c_int(NO_GROUP)
            if i > 0:
                # config.set_disabled(False)
                group_fd = self._counters[0].raw_fd()

            var file = _open_event(
                event,
                config^,
                cpu,
                process,
                flag,
                mode,
                virtualization,
                group_fd,
            )
            var counter = Counter(event=event, unsafe_file=file^)
            self._counters.append(counter^)

    @always_inline
    def _leader_fd(self) -> c_int:
        return self._counters[0].raw_fd()

    def id(self) -> UInt64:
        """Returns the unique id of the leader event assigned by the kernel.

        Returns:
            The leader event's unique id.
        """
        return self._counters[0].id()

    def __len__(self) -> Int:
        return len(self._counters)

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

    def read(self) raises -> Counts:
        """Read all values atomically in requested event order."""
        var fd = self._leader_fd()
        if fd < 0:
            raise Error("invalid file handle")

        var event_count = len(self._counters)
        var word_count = 3 + 2 * event_count
        var buffer = List[UInt64](length=word_count, fill=0)
        var bytes_read = perf_event_read(
            fd, buffer.unsafe_ptr(), c_size_t(len(buffer))
        )
        if bytes_read < 0:
            var err = get_errno()
            raise Error("failed to read event group: " + String(err))

        var expected_bytes = word_count * size_of[UInt64]()
        if Int(bytes_read) != expected_bytes:
            raise Error(
                t"invalid group read size: expected {expected_bytes} bytes, "
                t"received {bytes_read}"
            )
        if buffer[0] != UInt64(event_count):
            raise Error(
                t"invalid group event count: expected {event_count}, "
                t"received {buffer[0]}"
            )

        var values = List[UInt64](length=event_count, fill=0)
        var seen = List[Bool](length=event_count, fill=False)
        for read_index in range(event_count):
            var offset = 3 + 2 * read_index
            var value = buffer[offset]
            var event_id = buffer[offset + 1]

            var requested_index = -1
            for i in range(event_count):
                if self._counters[i].id() == event_id:
                    requested_index = i
                    break

            if requested_index < 0:
                raise Error(t"group read returned unknown event ID {event_id}")
            if seen[requested_index]:
                raise Error(
                    t"group read returned duplicate event ID {event_id}"
                )

            values[requested_index] = value
            seen[requested_index] = True

        return Counts(values^, buffer[1], buffer[2])
