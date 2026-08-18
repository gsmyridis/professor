"""Profiling with hardware performance counters.

A `Metric` does not have to be a single number. This example measures the wall
clock and three PMU events at once -- cycles, retired instructions, and L1D
load misses -- so the report prints one table per component, each with its own
totals and percentages. The zone that burns the most cycles is not necessarily
the one that misses the cache most, and neither is necessarily the one that
takes the most time, which is exactly why they get separate tables.

`blocking_work` is in here to make that last point unmissable. For a
CPU-bound thread at a steady clock the wall-clock and cycles tables are
near-copies of each other -- cycles are just time in another unit -- so
agreement between them proves little. A zone that sleeps breaks the tie: it
dominates the wall-clock table and barely registers in the cycles table,
because the kernel accumulates PMU counters per thread and only while that
thread is on a core.

The counters come from Apple's kperf via `professor.os.apple.Sampler`, which
needs elevated privileges:

    sudo pixi run example-counters

Note that `sample()` is not free -- a pair of reads costs on the order of ten
thousand instructions -- so hardware counters suit coarse zones. Zones smaller
than the sampling overhead measure mostly the measurement.
"""

from std.math import sqrt
from std.os import abort
from std.time import perf_counter_ns, sleep

from professor import (
    Count,
    Cycles,
    GlobalProfiler,
    Instrument,
    Metric,
    Nanos,
    ReportFormat,
)
from professor.os.apple import PortableEvent, Sampler, ThreadSampler


# ===----------------------------------------------------------------------=== #
# A four-component metric
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct PmuCounters(Metric):
    """One reading of the wall clock and of each counter this example programs.
    """

    var nanos: Nanos
    var cycles: Cycles
    var instructions: Count["instructions"]
    var cache_misses: Count["L1D load misses"]


# ===----------------------------------------------------------------------=== #
# The instrument
# ===----------------------------------------------------------------------=== #


struct Pmu(Instrument):
    """Reads the wall clock and the programmed counters for the calling thread.

    The `Sampler` is held for the profiler's lifetime because it owns the
    lease on the configurable counters; dropping it would hand them back.
    """

    comptime MetricType = PmuCounters

    var _sampler: Sampler
    var _thread: ThreadSampler

    def __init__(out self):
        # Zone open and close are non-raising, so a failure here can only
        # abort. `main` probes for privileges first to make that unlikely.
        try:
            var sampler = Sampler()
            var thread = sampler.thread(
                [
                    PortableEvent.Cycles,
                    PortableEvent.Instructions,
                    PortableEvent.L1DCacheMissLd,
                ]
            )
            thread.start()
            self._sampler = sampler^
            self._thread = thread^
        except e:
            abort(String(t"could not program the hardware counters: {e}"))

    def measure(mut self) -> PmuCounters:
        # The clock is read first at both ends of a zone, so a zone's wall
        # time carries exactly one counter read -- the one that opened it.
        var nanos = UInt64(perf_counter_ns())
        try:
            # Values come back in the order the events were added.
            var values = self._thread.sample()
            return PmuCounters(
                Nanos(nanos),
                Cycles(values[0]),
                Count["instructions"](values[1]),
                Count["L1D load misses"](values[2]),
            )
        except e:
            abort(String(t"could not read the hardware counters: {e}"))


comptime Prof = GlobalProfiler[Pmu, Tag="counters"]


# ===----------------------------------------------------------------------=== #
# Workload
# ===----------------------------------------------------------------------=== #


def integer_work(n: Int) -> Int:
    """Cycle-hungry, cache-friendly: everything stays in registers."""
    with Prof.zone["integer_work", 0]():
        var acc = 0
        for i in range(n):
            acc = (acc * 31 + i) % 1_000_003
        return acc


def float_work(n: Int) -> Float64:
    with Prof.zone["float_work", 1]():
        var acc = 0.0
        for i in range(n):
            acc += sqrt(Float64(i) + 1.0)
        return acc


def scattered_work(mut data: List[Int], n: Int) -> Int:
    """Cache-hostile: strides through a buffer far larger than L1."""
    with Prof.zone["scattered_work", 2]():
        var acc = 0
        var stride = 4099  # Prime, so it walks the whole buffer.
        var index = 0
        for _ in range(n):
            index = (index + stride) % len(data)
            acc += data[index]
        return acc


def blocking_work(seconds: Float64):
    """Off-CPU: waits without computing, so the two clocks disagree.

    The wall clock keeps running while the thread is descheduled; the counters
    do not. Reading both is what distinguishes a zone that is waiting from one
    that is working -- either alone would call this zone cheap or expensive
    and be half wrong.
    """
    with Prof.zone["blocking_work", 3]():
        sleep(seconds)


def main() raises:
    # Probe before starting: the profiler builds its instrument lazily inside
    # start(), and a failure there could only abort.
    try:
        _ = Sampler()
    except e:
        print("cannot take control of the hardware counters:", e)
        print()
        print("kperf needs elevated privileges. Run:")
        print("    sudo pixi run example-counters")
        return

    var data = List[Int](length=1 << 20, fill=0)
    for i in range(len(data)):
        data[i] = i

    Prof.start()

    var total = 0
    for _ in range(10):
        total += integer_work(50_000)
        total += Int(float_work(50_000))
        total += scattered_work(data, 50_000)
        blocking_work(0.002)

    Prof.end()

    print("result:", total)
    var format = ReportFormat(max_decimals=3)
    print(Prof.report(format^))
