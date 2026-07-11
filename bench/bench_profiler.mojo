from std.benchmark import keep
from std.time import perf_counter_ns
from std.benchmark import black_box

from professor.measure import Sample, Measurer
from professor.measure.default import WallClock
from professor.profile import Profiler


# A measurer whose sample is empty and whose reading costs nothing: zone
# open/close through it measures pure profiler bookkeeping (state fetch, site
# probe, serial stack, anchor update) with no clock reads.
struct NullSample(Sample, Defaultable, ImplicitlyCopyable):
    def __init__(out self):
        pass

    def __sub__(self, other: Self) -> Self:
        return Self()

    def __add__(self, other: Self) -> Self:
        return Self()

    def __mul__(self, other: Self) -> Self:
        return Self()

    def __truediv__(self, count: Int) -> Self:
        return Self()

    def min(self, other: Self) -> Self:
        return Self()

    def max(self, other: Self) -> Self:
        return Self()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("-")


struct NullClock(Measurer):
    comptime S = NullSample

    def __init__(out self):
        pass

    def measure(mut self) -> NullSample:
        return NullSample()


comptime WallProf = Profiler[WallClock, "bench.wall"]
comptime NullProf = Profiler[NullClock, "bench.null"]

comptime REPS = 5


def bench_baseline(n: Int) -> Float64:
    var acc = 0
    var t0 = Int(perf_counter_ns())
    for i in range(n):
        acc += i
        keep(acc)
    var t1 = Int(perf_counter_ns())
    return Float64(t1 - t0) / Float64(n)


def bench_clock_pair(n: Int) -> Float64:
    var acc = 0
    var t0 = Int(perf_counter_ns())
    for i in range(n):
        var a = Int(perf_counter_ns())
        acc += i
        keep(acc)
        var b = Int(perf_counter_ns())
        keep(a)
        keep(b)
    var t1 = Int(perf_counter_ns())
    return Float64(t1 - t0) / Float64(n)


def bench_state_fetch(n: Int) -> Float64:
    var acc = 0
    var t0 = Int(perf_counter_ns())
    for i in range(n):
        var st = WallProf._state()
        acc += i
        keep(acc)
        keep(st)
    var t1 = Int(perf_counter_ns())
    return Float64(t1 - t0) / Float64(n)


def bench_zone_null(n: Int) -> Float64:
    var acc = 0
    var t0 = Int(perf_counter_ns())
    for i in range(n):
        var z = NullProf.zone["bench"]()
        acc += i
        keep(acc)
        z^.close()
    var t1 = Int(perf_counter_ns())
    return Float64(t1 - t0) / Float64(n)


def bench_zone_wall(n: Int) -> Float64:
    var acc = 0
    var t0 = Int(perf_counter_ns())
    for i in range(n):
        var z = WallProf.zone["bench"]()
        acc += i
        keep(acc)
        z^.close()
    var t1 = Int(perf_counter_ns())
    return Float64(t1 - t0) / Float64(n)


def _min_of[f: def(Int) thin -> Float64](n: Int) -> Float64:
    var best = f(n)
    for _ in range(REPS - 1):
        var v = f(n)
        if v < best:
            best = v
    return best


def _fmt(x: Float64) -> Float64:
    return Float64(Int(x * 100)) / 100.0


def main() raises:
    WallProf.install(WallClock())
    NullProf.install(NullClock())

    var n = black_box(1_000_000)
    # Warmup: register sites, create globals, warm caches.
    _ = bench_baseline(n)
    _ = bench_zone_null(n)
    _ = bench_zone_wall(n)
    WallProf.reset()
    NullProf.reset()

    var base = _min_of[bench_baseline](n)
    var clock = _min_of[bench_clock_pair](n)
    var state = _min_of[bench_state_fetch](n)
    var znull = _min_of[bench_zone_null](n)
    var zwall = _min_of[bench_zone_wall](n)

    print("iterations per rep:", n, " reps:", REPS, " (min taken)")
    print("")
    print("baseline loop body          :", _fmt(base), "ns/iter")
    print("+ 2x perf_counter_ns        :", _fmt(clock), "ns/iter  (delta", _fmt(clock - base), "ns)")
    print("+ _state() fetch            :", _fmt(state), "ns/iter  (delta", _fmt(state - base), "ns)")
    print("+ zone open/close, NullClock:", _fmt(znull), "ns/iter  (delta", _fmt(znull - base), "ns)")
    print("+ zone open/close, WallClock:", _fmt(zwall), "ns/iter  (delta", _fmt(zwall - base), "ns)")
    print("")
    print("breakdown of WallClock zone pair (", _fmt(zwall - base), "ns ):")
    print("  clock reads (2x)          :", _fmt(clock - base), "ns")
    print("  bookkeeping (null zone)   :", _fmt(znull - base), "ns")
    print("    of which _state() fetch :", _fmt(state - base), "ns")
