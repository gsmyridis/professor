"""This is a smoke test to verify that the package is built and imported correctly."""

from professor import GlobalProfiler, WallClock

comptime Profiler = GlobalProfiler[WallClock]


def main():
    Profiler.start()

    var list = List[Int]()
    with Profiler.zone["append"]():
        for i in range(100_000):
            list.append(i**2)

    var sum = 0
    with Profiler.zone["sum"]():
        for element in list:
            sum += element

    Profiler.end()
    var report = Profiler.report()
    print(report)
