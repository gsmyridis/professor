from std.testing import assert_equal, assert_raises, assert_true, TestSuite

from professor import (
    Instrument,
    Metric,
    MetricField,
    Profiler,
    RepetitionTester,
)


@fieldwise_init
struct PairMetric(Defaultable, ImplicitlyCopyable, Metric):
    var cycles: Int
    var instructions: Int

    def __init__(out self):
        self = Self(0, 0)

    def __sub__(self, other: Self) -> Self:
        return Self(
            self.cycles - other.cycles,
            self.instructions - other.instructions,
        )

    def __add__(self, other: Self) -> Self:
        return Self(
            self.cycles + other.cycles,
            self.instructions + other.instructions,
        )

    def __truediv__(self, count: Int) -> Self:
        return Self(self.cycles // count, self.instructions // count)

    def min(self, other: Self) -> Self:
        return Self(
            min(self.cycles, other.cycles),
            min(self.instructions, other.instructions),
        )

    def max(self, other: Self) -> Self:
        return Self(
            max(self.cycles, other.cycles),
            max(self.instructions, other.instructions),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.cycles, " cycles, ", self.instructions, " insns")

    def fields(self) -> List[MetricField]:
        return [
            MetricField("cycles", String(self.cycles), Float64(self.cycles)),
            MetricField(
                "instructions",
                String(self.instructions),
                Float64(self.instructions),
            ),
        ]


struct RepetitionInstrument(Instrument):
    """Produces wrapper spans (5, 5), then (5, 4) for every later run."""

    comptime MetricType = PairMetric

    var calls: Int
    var now: PairMetric

    def __init__(out self):
        self.calls = 0
        self.now = PairMetric()

    def measure(mut self) -> PairMetric:
        var phase = self.calls % 4
        var repetition = self.calls // 4
        self.calls += 1

        # Each repetition samples start, wrapper-open, wrapper-close, end.
        if phase == 2:
            self.now.cycles += 5
            self.now.instructions += 5 if repetition == 0 else 4
        return self.now


comptime PatienceProf = Profiler[
    RepetitionInstrument, Tag="test.reptest.patience"
]
comptime LimitProf = Profiler[RepetitionInstrument, Tag="test.reptest.limit"]
comptime ErrorProf = Profiler[RepetitionInstrument, Tag="test.reptest.error"]


def do_nothing() raises:
    pass


def fail() raises:
    raise Error("test failure")


def test_any_component_improvement_resets_patience() raises:
    var tester = RepetitionTester[
        profiler=PatienceProf,
        function=do_nothing,
        reps=2,
    ](print_results=False)

    var report = tester.run()
    assert_equal(len(report.zones), 1)
    assert_equal(report.zones[0].count, 4)
    assert_equal(report.zones[0].inclusive_min.cycles, 5)
    assert_equal(report.zones[0].inclusive_min.instructions, 4)


def test_max_reps_places_a_hard_limit() raises:
    var tester = RepetitionTester[
        profiler=LimitProf,
        function=do_nothing,
        reps=10,
    ](max_reps=2, print_results=False)

    var report = tester.run()
    assert_equal(report.zones[0].count, 2)


def test_invalid_max_reps_raises() raises:
    with assert_raises(contains="greater than zero"):
        _ = RepetitionTester[
            profiler=LimitProf,
            function=do_nothing,
        ](max_reps=0)


def test_function_error_resets_profiler_before_propagating() raises:
    var tester = RepetitionTester[
        profiler=ErrorProf,
        function=fail,
    ](print_results=False)

    with assert_raises(contains="test failure"):
        _ = tester.run()

    ErrorProf.start()
    ErrorProf.end()
    ErrorProf.reset()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
