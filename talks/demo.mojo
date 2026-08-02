"""Slide demo: four zones, one of them nested, one report.

    pixi run mojo run -I src talks/demo.mojo
"""

from std.benchmark import black_box, keep
from std.math import sqrt

from professor import GlobalProfiler
from professor.measure.default import WallClock

comptime Profiler = GlobalProfiler[WallClock]


def do_work():
    var zone = Profiler.zone["do_work"]()

    var acc = 0.0
    for i in range(black_box(190_000)):
        acc += sqrt(Float64(i) + 1.0)
    keep(acc)


def do_more_work() -> Int:
    with Profiler.zone["do_more_work"]():
        var acc = 0
        for i in range(black_box(5_000)):
            acc = (acc * 31 + i) % 1_000_003

        do_work()

        for i in range(black_box(3_500)):
            acc = (acc * 17 + i) % 1_000_003
        return acc


def do_other_work() -> Int:
    var acc = 0
    for i in range(black_box(18_500)):
        acc = (acc * 31 + i) % 1_000_003
    return acc


def do_final_work() -> Float64:
    var acc = 0.0
    for i in range(black_box(105_000)):
        acc += sqrt(Float64(i) + 1.0)
    return acc


def main() raises:
    Profiler.start()

    var total = 0
    for _ in range(100):
        total += do_more_work()
        total += do_other_work()
        total += Int(do_final_work())

    Profiler.end()

    print("result:", total, "\n")
    print(Profiler.report())
