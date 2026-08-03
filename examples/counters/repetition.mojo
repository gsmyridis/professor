"""Repetition testing with Apple hardware performance counters.

This repeatedly measures one CPU-bound workload until no counter component
finds a new minimum for ten consecutive runs. It uses the same PMU instrument
as `main.mojo`, so the result contains separate tables for wall-clock time,
cycles, retired instructions, and L1D load misses.

Apple's kperf interface needs elevated privileges:

    sudo pixi run example-counters-repetition
"""

from std.benchmark import black_box, keep

from main import Pmu
from professor import RepetitionTester
from professor.measure import WallClock
from professor.os.apple import Sampler


def integer_work() raises:
    var count = 250_000
    var limit = black_box(count)
    var acc = 0
    for i in range(limit):
        acc = (acc * 31 + i) % 1_000_003
    keep(acc)


def main() raises:
    try:
        _ = Sampler()
    except e:
        print("cannot take control of the hardware counters:", e)
        print()
        print("kperf needs elevated privileges. Run:")
        print("    sudo pixi run example-counters-repetition")
        return

    var tester = RepetitionTester(
        WallClock(),
        patience=20,
        max_repetitions=1_000,
    )
    _ = tester.run[integer_work]()
