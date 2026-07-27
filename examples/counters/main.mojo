"""Profiling with hardware performance counters.

A `Metric` does not have to be a single number. This example measures three
PMU events at once -- cycles, retired instructions, and L1D load misses -- so
the report prints one table per event, each with its own totals and
percentages. The zone that burns the most cycles is not necessarily the one
that misses the cache most, which is exactly why they get separate tables.

The counters come from Apple's kperf via `professor.os.apple.Sampler`, which
needs elevated privileges:

    sudo pixi run example-counters

Note that `sample()` is not free -- a pair of reads costs on the order of ten
thousand instructions -- so hardware counters suit coarse zones. Zones smaller
than the sampling overhead measure mostly the measurement.
"""

from std.math import sqrt
from std.os import abort

from professor import Instrument, Metric, MetricField, Profiler
from professor.os.apple import PortableEvent, Sampler, ThreadSampler


# ===----------------------------------------------------------------------=== #
# A three-component metric
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct PmuCounters(Defaultable, ImplicitlyCopyable, Metric):
    """One reading of each counter this example programs."""

    var cycles: Int
    var instructions: Int
    var cache_misses: Int

    def __init__(out self):
        self = Self(0, 0, 0)

    def __sub__(self, o: Self) -> Self:
        return Self(
            self.cycles - o.cycles,
            self.instructions - o.instructions,
            self.cache_misses - o.cache_misses,
        )

    def __add__(self, o: Self) -> Self:
        return Self(
            self.cycles + o.cycles,
            self.instructions + o.instructions,
            self.cache_misses + o.cache_misses,
        )

    def __mul__(self, o: Self) -> Self:
        return Self(
            self.cycles * o.cycles,
            self.instructions * o.instructions,
            self.cache_misses * o.cache_misses,
        )

    def __truediv__(self, count: Int) -> Self:
        return Self(
            self.cycles // count,
            self.instructions // count,
            self.cache_misses // count,
        )

    def min(self, o: Self) -> Self:
        return Self(
            min(self.cycles, o.cycles),
            min(self.instructions, o.instructions),
            min(self.cache_misses, o.cache_misses),
        )

    def max(self, o: Self) -> Self:
        return Self(
            max(self.cycles, o.cycles),
            max(self.instructions, o.instructions),
            max(self.cache_misses, o.cache_misses),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            self.cycles,
            " cycles, ",
            self.instructions,
            " insns, ",
            self.cache_misses,
            " misses",
        )

    def fields(self) -> List[MetricField]:
        """Names the components so the report can tabulate them separately.

        The third element of each field is the scalar used for percentages.
        Pass `None` for a component that should show `N/A` instead -- a
        derived ratio such as instructions per cycle, which would be a fine
        fourth field here, is not a share of anything.
        """
        return [
            MetricField("cycles", String(self.cycles), Float64(self.cycles)),
            MetricField(
                "instructions",
                String(self.instructions),
                Float64(self.instructions),
            ),
            MetricField(
                "L1D load misses",
                String(self.cache_misses),
                Float64(self.cache_misses),
            ),
        ]


# ===----------------------------------------------------------------------=== #
# The instrument
# ===----------------------------------------------------------------------=== #


struct Pmu(Instrument):
    """Reads the programmed counters for the calling thread.

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
        try:
            # Values come back in the order the events were added.
            var values = self._thread.sample()
            return PmuCounters(Int(values[0]), Int(values[1]), Int(values[2]))
        except e:
            abort(String(t"could not read the hardware counters: {e}"))


comptime Prof = Profiler[Pmu, Tag="counters"]


# ===----------------------------------------------------------------------=== #
# Workload
# ===----------------------------------------------------------------------=== #


def integer_work(n: Int) -> Int:
    """Cycle-hungry, cache-friendly: everything stays in registers."""
    with Prof.zone["integer_work"]():
        var acc = 0
        for i in range(n):
            acc = (acc * 31 + i) % 1_000_003
        return acc


def float_work(n: Int) -> Float64:
    with Prof.zone["float_work"]():
        var acc = 0.0
        for i in range(n):
            acc += sqrt(Float64(i) + 1.0)
        return acc


def scattered_work(mut data: List[Int], n: Int) -> Int:
    """Cache-hostile: strides through a buffer far larger than L1."""
    with Prof.zone["scattered_work"]():
        var acc = 0
        var stride = 4099  # Prime, so it walks the whole buffer.
        var index = 0
        for _ in range(n):
            index = (index + stride) % len(data)
            acc += data[index]
        return acc


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

    Prof.end()

    print("result:", total, "\n")
    print(Prof.report())
