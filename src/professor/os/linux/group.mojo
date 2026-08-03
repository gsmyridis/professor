from std.sys._libc_errno import get_errno
from std.ffi import c_int, c_size_t
from std.sys.info import size_of

from .counter import _CounterHandle, _open_event, NO_GROUP
from .sys import (
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
from .config import Config, CounterConfig, Flag, CpuId, ProcessId
from ._event import PerfEvent
from ._token import CounterToken
from .counts import Counts

# ===------------------------------------------------------------------------===
# Group
# ===------------------------------------------------------------------------===


struct Group(Movable, Sized):
    """An owned group of simultaneously scheduled counting events.

    The group owns a hidden dummy leader and every requested counter. Members
    are addressed using the `CounterToken`s returned by `GroupBuilder.add`.
    """

    var _leader: _CounterHandle
    """Hidden dummy event used as the stable kernel group leader."""

    var _counters: List[_CounterHandle]
    """Owned user-requested counters."""

    var _enabled: Bool
    """True if the group is enabled."""

    def __init__(
        out self,
        *,
        var unsafe_leader: _CounterHandle,
        var unsafe_counters: List[_CounterHandle],
    ):
        self._leader = unsafe_leader^
        self._counters = unsafe_counters^
        self._enabled = False

    @always_inline
    def _leader_fd(self) -> c_int:
        return self._leader.raw_fd()

    def id(self) -> UInt64:
        """Return the kernel ID of the hidden group leader."""
        return self._leader.id()

    def __len__(self) -> Int:
        return len(self._counters)

    def __contains__(self, token: CounterToken) -> Bool:
        return Bool(self._index_of(token))

    def _index_of(self, token: CounterToken) -> Optional[Int]:
        if token._group_id != self.id():
            return None
        for i in range(len(self._counters)):
            if self._counters[i].id() == token._event_id:
                return i
        return None

    def remove(mut self, token: CounterToken) raises:
        """Close and remove a counter while the group is disabled."""
        if self._enabled:
            raise Error("cannot remove a counter while its group is enabled")

        var index = self._index_of(token)
        if not index:
            raise Error("counter token does not belong to this group")

        var removed = self._counters.pop(index.value())
        removed.close()

    def enable(mut self) raises:
        """Enable every counter in the group atomically."""
        if perf_event_enable(self._leader_fd(), PERF_IOC_FLAG_GROUP) != 0:
            var err = get_errno()
            raise Error(t"failed to enable event group: {err}")
        self._enabled = True

    def disable(mut self) raises:
        """Disable every counter in the group atomically."""
        if perf_event_disable(self._leader_fd(), PERF_IOC_FLAG_GROUP) != 0:
            var err = get_errno()
            raise Error(t"failed to disable event group: {err}")
        self._enabled = False

    def reset(mut self) raises:
        """Reset every event count without resetting multiplexing times."""
        if perf_event_reset(self._leader_fd(), PERF_IOC_FLAG_GROUP) != 0:
            var err = get_errno()
            raise Error(t"failed to reset event group: {err}")

    def read(self) raises -> Counts:
        """Read all member values atomically."""
        var fd = self._leader_fd()
        if fd < 0:
            raise Error("invalid file handle")

        var counter_count = len(self._counters)
        var kernel_event_count = counter_count + 1
        var word_count = 3 + 2 * kernel_event_count
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
        if buffer[0] != UInt64(kernel_event_count):
            raise Error(
                t"invalid group event count: expected {kernel_event_count}, "
                t"received {buffer[0]}"
            )

        var values = List[UInt64](length=counter_count, fill=0)
        var seen = List[Bool](length=counter_count, fill=False)
        for read_index in range(kernel_event_count):
            var offset = 3 + 2 * read_index
            var value = buffer[offset]
            var event_id = buffer[offset + 1]

            if event_id == self.id():
                continue

            var requested_index = -1
            for i in range(counter_count):
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

        var tokens = List[CounterToken](capacity=counter_count)
        for i in range(counter_count):
            tokens.append(
                CounterToken(
                    unsafe_group_id=self.id(),
                    unsafe_event_id=self._counters[i].id(),
                )
            )

        return Counts(tokens^, values^, buffer[1], buffer[2])


# ===------------------------------------------------------------------------===
# Group builder
# ===------------------------------------------------------------------------===


@explicit_destroy("The group builder must be consumed with: .build()")
struct GroupBuilder(Movable, Sized):
    """Build an owned group from independently configured counters."""

    var _leader: _CounterHandle
    var _counters: List[_CounterHandle]
    var _cpu: CpuId
    var _process: ProcessId
    var _flag: Flag

    def __init__(
        out self,
        *,
        cpu: CpuId = CpuId.Any,
        process: ProcessId = ProcessId.Calling,
        flag: Flag = Flag.CloseOnExec,
    ) raises:
        if Flag.NoGroup in flag:
            raise Error("cannot set Flag.NoGroup for a group")

        var config = Config()
        config.read_format = (
            PERF_FORMAT_GROUP
            | PERF_FORMAT_ID
            | PERF_FORMAT_TOTAL_TIME_ENABLED
            | PERF_FORMAT_TOTAL_TIME_RUNNING
        )
        var leader_config = CounterConfig(PerfEvent.Dummy)
        var file = _open_event(
            leader_config,
            config^,
            cpu,
            process,
            flag,
            NO_GROUP,
            disabled=True,
        )

        self._leader = _CounterHandle(PerfEvent.Dummy, file^)
        self._counters = List[_CounterHandle]()
        self._cpu = cpu
        self._process = process
        self._flag = flag

    def __len__(self) -> Int:
        return len(self._counters)

    def contains(self, token: CounterToken) -> Bool:
        return self._index_of(token) >= 0

    def _index_of(self, token: CounterToken) -> Int:
        if token._group_id != self._leader.id():
            return -1
        for i in range(len(self._counters)):
            if self._counters[i].id() == token._event_id:
                return i
        return -1

    def add(mut self, counter_config: CounterConfig) raises -> CounterToken:
        """Open and add one independently configured counter."""
        var config = Config()
        config.read_format = (
            PERF_FORMAT_TOTAL_TIME_ENABLED | PERF_FORMAT_TOTAL_TIME_RUNNING
        )
        var file = _open_event(
            counter_config,
            config^,
            self._cpu,
            self._process,
            self._flag,
            self._leader.raw_fd(),
            disabled=False,
        )
        var counter = _CounterHandle(counter_config.event, file^)
        var token = CounterToken(
            unsafe_group_id=self._leader.id(),
            unsafe_event_id=counter.id(),
        )
        self._counters.append(counter^)
        return token

    def remove(mut self, token: CounterToken) raises:
        """Close and remove a counter before building the group."""
        var index = self._index_of(token)
        if index < 0:
            raise Error("counter token does not belong to this builder")

        var removed = self._counters.pop(index)
        removed.close()

    def build(deinit self) raises -> Group:
        """Transfer the completed group into its runtime owner."""
        if len(self._counters) == 0:
            raise Error("cannot build an empty event group")
        return Group(
            unsafe_leader=self._leader^,
            unsafe_counters=self._counters^,
        )
