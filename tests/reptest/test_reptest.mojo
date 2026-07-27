from std.testing import assert_equal, assert_raises, TestSuite

from professor import (
    Instrument,
    Metric,
    MetricField,
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
    """Produces spans (5, 5), then (5, 4) for every later run."""

    comptime MetricType = PairMetric

    var calls: Int
    var now: PairMetric

    def __init__(out self):
        self.calls = 0
        self.now = PairMetric()

    def measure(mut self) -> PairMetric:
        var phase = self.calls % 2
        var repetition = self.calls // 2
        self.calls += 1

        # Each repetition samples immediately before and after the function.
        if phase == 1:
            self.now.cycles += 5
            self.now.instructions += 5 if repetition == 0 else 4
        return self.now


def do_nothing() raises:
    pass


def fail() raises:
    raise Error("test failure")


def test_any_component_improvement_resets_patience() raises:
    var tester = RepetitionTester(
        RepetitionInstrument(),
        patience=2,
    )

    var report = tester.run[do_nothing]()
    assert_equal(report.results.test_count, 4)
    assert_equal(report.results.minimum.cycles, 5)
    assert_equal(report.results.minimum.instructions, 4)
    assert_equal(report.results.maximum.cycles, 5)
    assert_equal(report.results.maximum.instructions, 5)
    assert_equal(report.results.average().cycles, 5)
    assert_equal(report.results.average().instructions, 4)


def test_max_repetitions_places_a_hard_limit() raises:
    var tester = RepetitionTester(
        RepetitionInstrument(),
        patience=10,
        max_repetitions=2,
    )

    var report = tester.run[do_nothing]()
    assert_equal(report.results.test_count, 2)


def test_invalid_max_repetitions_raises() raises:
    with assert_raises(contains="greater than zero"):
        _ = RepetitionTester(
            RepetitionInstrument(),
            max_repetitions=0,
        )


def test_invalid_patience_raises() raises:
    with assert_raises(contains="greater than zero"):
        _ = RepetitionTester(
            RepetitionInstrument(),
            patience=0,
        )


def test_function_error_does_not_poison_tester() raises:
    var tester = RepetitionTester(RepetitionInstrument())

    with assert_raises(contains="test failure"):
        _ = tester.run[fail]()

    # The instrument remains usable after the function propagates an error.
    with assert_raises(contains="test failure"):
        _ = tester.run[fail]()


def test_report_renders_each_metric_component() raises:
    var tester = RepetitionTester(
        RepetitionInstrument(),
        patience=1,
        max_repetitions=2,
    )

    var text = String(tester.run[do_nothing]())
    assert_equal(text.find("cycles — 2 repetitions") >= 0, True)
    assert_equal(text.find("instructions — 2 repetitions") >= 0, True)
    assert_equal(text.find("Minimum") >= 0, True)
    assert_equal(text.find("Maximum") >= 0, True)
    assert_equal(text.find("Average") >= 0, True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
