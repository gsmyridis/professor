"""Count cycles, retired instructions, and L1 data-cache read misses.

Run this example on Linux:

    mojo run -I src examples/linux/measure.mojo

Access to performance counters depends on the host's perf security policy.
"""

from std.benchmark import black_box
from professor.os.linux import (
    CounterConfig,
    CounterToken,
    GroupBuilder,
    PerfEvent,
)

comptime ELEMENT_COUNT = 1 << 20
comptime POINTER_STRIDE = 8191
comptime POINTER_CHASE_STEPS = 8 * ELEMENT_COUNT


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


def measure() raises:
    """Measure the example workload with one simultaneously scheduled group."""
    var data = _make_pointer_chase()

    var builder = GroupBuilder()
    var cycles_token: CounterToken
    var instructions_token: CounterToken
    var l1d_read_misses_token: CounterToken
    try:
        cycles_token = builder.add(CounterConfig(PerfEvent.CpuCycles))
        instructions_token = builder.add(CounterConfig(PerfEvent.Instructions))
        l1d_read_misses_token = builder.add(
            CounterConfig(PerfEvent.L1DReadMiss)
        )
    except error:
        # Consume the explicit-destroy builder even when event setup fails.
        try:
            _ = builder^.build()
        except:
            pass
        raise error^
    var group = builder^.build()
    group.reset()
    group.enable()
    var result = _pointer_chase(data)
    group.disable()

    var counts = group.read()
    if counts.time_running == 0:
        raise Error(
            "the event group was never scheduled; its events may not fit "
            "together on this CPU"
        )

    var cycles = counts.count(cycles_token)
    var instructions = counts.count(instructions_token)
    var l1d_read_misses = counts.count(l1d_read_misses_token)

    print("workload result:", result)
    print("time enabled (ns):", counts.time_enabled)
    print("time running (ns):", counts.time_running)
    print("cycles:", cycles.value)
    print("retired instructions:", instructions.value)
    print("L1D read misses:", l1d_read_misses.value)

    if counts.time_running != counts.time_enabled:
        print("scaled cycles:", cycles.scaled())
        print("scaled retired instructions:", instructions.scaled())
        print("scaled L1D read misses:", l1d_read_misses.scaled())


def main() raises:
    measure()
