"""Count cycles, retired instructions, and L1 data-cache read misses.

Run this example on Linux:

    mojo run -I src examples/linux/measure.mojo

Access to performance counters depends on the host's perf security policy.
"""

from std.benchmark import black_box
from std.ffi import (
    c_int,
    c_size_t,
    c_ssize_t,
    c_ulong,
    external_call,
    get_errno,
)
from std.sys import size_of

from professor.os.linux.ffi import (
    PERF_COUNT_HW_CACHE_L1D,
    PERF_COUNT_HW_CACHE_OP_READ,
    PERF_COUNT_HW_CACHE_RESULT_MISS,
    PERF_COUNT_HW_CPU_CYCLES,
    PERF_COUNT_HW_INSTRUCTIONS,
    PERF_FLAG_FD_CLOEXEC,
    PERF_FORMAT_GROUP,
    PERF_FORMAT_ID,
    PERF_FORMAT_TOTAL_TIME_ENABLED,
    PERF_FORMAT_TOTAL_TIME_RUNNING,
    PERF_IOC_FLAG_GROUP,
    PERF_TYPE_HARDWARE,
    PERF_TYPE_HW_CACHE,
    PerfEventAttr,
    perf_event_disable,
    perf_event_enable,
    perf_event_id,
    perf_event_open,
    perf_event_read,
    perf_event_reset,
    perf_hw_cache_config,
)

comptime EVENT_COUNT = 3
comptime GROUP_READ_WORDS = 3 + 2 * EVENT_COUNT
comptime ELEMENT_COUNT = 1 << 20
comptime POINTER_STRIDE = 8191
comptime POINTER_CHASE_STEPS = 8 * ELEMENT_COUNT


@always_inline
def _close(fd: c_int):
    if fd >= 0:
        _ = external_call["close", c_int](fd)


struct EventGroup(Movable):
    """Own the file descriptors for one perf event group."""

    var leader: c_int
    var instructions: c_int
    var l1d_read_misses: c_int

    def __init__(out self):
        self.leader = -1
        self.instructions = -1
        self.l1d_read_misses = -1

    def __del__(deinit self):
        _close(self.l1d_read_misses)
        _close(self.instructions)
        _close(self.leader)

    def read[
        origin: MutOrigin,
    ](
        self,
        values: UnsafePointer[UInt64, origin],
        value_capacity: c_size_t,
    ) -> c_ssize_t:
        """Read the group leader while keeping every owned fd alive."""
        return perf_event_read(self.leader, values, value_capacity)


def _event_attr(type_: UInt32, config: UInt64) -> PerfEventAttr:
    """Create a user-space counting attribute for a group event."""
    var attr = PerfEventAttr()
    attr.type_ = type_
    attr.config = config
    attr.read_format = (
        PERF_FORMAT_GROUP
        | PERF_FORMAT_ID
        | PERF_FORMAT_TOTAL_TIME_ENABLED
        | PERF_FORMAT_TOTAL_TIME_RUNNING
    )
    attr.set_disabled()
    attr.set_exclude_kernel()
    attr.set_exclude_hv()
    return attr^


def _open_event(
    type_: UInt32,
    config: UInt64,
    group_fd: c_int,
    name: StringSlice,
) raises -> c_int:
    """Open one event for the calling thread on any CPU."""
    var attr = _event_attr(type_, config)
    var fd = perf_event_open(
        UnsafePointer(to=attr),
        c_int(0),
        c_int(-1),
        group_fd,
        c_ulong(PERF_FLAG_FD_CLOEXEC),
    )
    if fd < 0:
        raise Error(t"perf_event_open({name}) failed: {get_errno()}")
    return fd


def _get_event_id(fd: c_int, name: StringSlice) raises -> UInt64:
    """Return the stable ID used to identify an entry in a group read."""
    var event_id: UInt64 = 0
    if perf_event_id(fd, UnsafePointer(to=event_id)) < 0:
        raise Error(t"PERF_EVENT_IOC_ID({name}) failed: {get_errno()}")
    return event_id


def _check_ioctl(result: c_int, operation: StringSlice) raises:
    """Raise an error when a perf event ioctl fails."""
    if result < 0:
        raise Error(t"{operation} failed: {get_errno()}")


def _make_pointer_chase() -> List[UInt64]:
    """Build an 8 MiB dependent-load cycle that exceeds a typical L1 cache."""
    var data = List[UInt64](capacity=ELEMENT_COUNT)
    for i in range(ELEMENT_COUNT):
        data.append(UInt64((i + POINTER_STRIDE) & (ELEMENT_COUNT - 1)))
    return data^


@no_inline
def _pointer_chase(data: List[UInt64]) -> UInt64:
    """Execute dependent loads whose working set is larger than L1."""
    var index = 0
    for _ in range(POINTER_CHASE_STEPS):
        index = Int(data[index])
    return black_box(UInt64(index))


def _find_count(
    read_data: InlineArray[UInt64, GROUP_READ_WORDS],
    event_id: UInt64,
) raises -> UInt64:
    """Find an event value in a `PERF_FORMAT_GROUP | PERF_FORMAT_ID` read."""
    for i in range(EVENT_COUNT):
        var offset = 3 + 2 * i
        if read_data[offset + 1] == event_id:
            return read_data[offset]
    raise Error(t"event ID {event_id} was absent from the group read")


def _scaled_count(
    value: UInt64,
    time_enabled: UInt64,
    time_running: UInt64,
) -> Float64:
    """Scale a multiplexed counter value to the full enabled interval."""
    return Float64(value) * Float64(time_enabled) / Float64(time_running)


def measure() raises:
    """Measure the example workload with one simultaneously scheduled group."""
    var group = EventGroup()

    group.leader = _open_event(
        PERF_TYPE_HARDWARE,
        PERF_COUNT_HW_CPU_CYCLES,
        c_int(-1),
        "cycles",
    )
    group.instructions = _open_event(
        PERF_TYPE_HARDWARE,
        PERF_COUNT_HW_INSTRUCTIONS,
        group.leader,
        "instructions",
    )
    group.l1d_read_misses = _open_event(
        PERF_TYPE_HW_CACHE,
        perf_hw_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
        group.leader,
        "L1D read misses",
    )

    var cycles_id = _get_event_id(group.leader, "cycles")
    var instructions_id = _get_event_id(group.instructions, "instructions")
    var misses_id = _get_event_id(group.l1d_read_misses, "L1D read misses")

    var data = _make_pointer_chase()

    _check_ioctl(
        perf_event_reset(group.leader, PERF_IOC_FLAG_GROUP),
        "group reset",
    )
    _check_ioctl(
        perf_event_enable(group.leader, PERF_IOC_FLAG_GROUP),
        "group enable",
    )
    var result = _pointer_chase(data)
    _check_ioctl(
        perf_event_disable(group.leader, PERF_IOC_FLAG_GROUP),
        "group disable",
    )

    var read_data = InlineArray[UInt64, GROUP_READ_WORDS](fill=0)
    var bytes_read = group.read(
        read_data.unsafe_ptr(),
        c_size_t(len(read_data)),
    )
    comptime expected_bytes = GROUP_READ_WORDS * size_of[UInt64]()
    if bytes_read != c_ssize_t(expected_bytes):
        if bytes_read < 0:
            raise Error(t"group read failed: {get_errno()}")
        raise Error(
            t"group read returned {bytes_read} bytes; expected {expected_bytes}"
        )
    if read_data[0] != EVENT_COUNT:
        raise Error(
            t"group read returned {read_data[0]} events; expected {EVENT_COUNT}"
        )

    var time_enabled = read_data[1]
    var time_running = read_data[2]
    if time_running == 0:
        raise Error(
            "the event group was never scheduled; its events may not fit "
            "together on this CPU"
        )

    var cycles = _find_count(read_data, cycles_id)
    var instructions = _find_count(read_data, instructions_id)
    var l1d_read_misses = _find_count(read_data, misses_id)

    print("workload result:", result)
    print("time enabled (ns):", time_enabled)
    print("time running (ns):", time_running)
    print("cycles:", cycles)
    print("retired instructions:", instructions)
    print("L1D read misses:", l1d_read_misses)

    if time_running != time_enabled:
        print(
            "scaled cycles:", _scaled_count(cycles, time_enabled, time_running)
        )
        print(
            "scaled retired instructions:",
            _scaled_count(instructions, time_enabled, time_running),
        )
        print(
            "scaled L1D read misses:",
            _scaled_count(l1d_read_misses, time_enabled, time_running),
        )


def main() raises:
    measure()
