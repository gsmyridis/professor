from std.testing import assert_equal, assert_raises, TestSuite

from professor import (
    Instrument,
    Metric,
    MetricField,
    RepetitionTester,
)
from professor.reptest import _repetition_table


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

    var results = tester.run(do_nothing)
    assert_equal(results.test_count, 4)
    assert_equal(results.minimum.cycles, 5)
    assert_equal(results.minimum.instructions, 4)
    assert_equal(results.maximum.cycles, 5)
    assert_equal(results.maximum.instructions, 5)
    assert_equal(results.average().cycles, 5)
    assert_equal(results.average().instructions, 4)


def test_max_reps_places_a_hard_limit() raises:
    var tester = RepetitionTester(
        RepetitionInstrument(),
        patience=10,
        max_reps=2,
    )

    var results = tester.run(do_nothing)
    assert_equal(results.test_count, 2)


def test_invalid_max_reps_raises() raises:
    with assert_raises(contains="greater than zero"):
        _ = RepetitionTester(
            RepetitionInstrument(),
            max_reps=0,
        )


def test_invalid_patience_raises() raises:
    with assert_raises(contains="greater than zero"):
        _ = RepetitionTester(
            RepetitionInstrument(),
            patience=0,
        )


def test_invalid_batch_reps_raises() raises:
    with assert_raises(contains="greater than zero"):
        _ = RepetitionTester(
            RepetitionInstrument(),
            batch_reps=0,
        )


def test_batch_reps_count_function_calls_and_respect_limit() raises:
    var calls = 0

    def count_call() raises {mut calls}:
        calls += 1

    var tester = RepetitionTester(
        RepetitionInstrument(),
        patience=10,
        batch_reps=2,
        max_reps=3,
    )

    var results = tester.run(count_call)
    assert_equal(calls, 3)
    assert_equal(results.test_count, 3)
    assert_equal(results.minimum.cycles, 2)
    assert_equal(results.maximum.cycles, 5)
    assert_equal(results.average().cycles, 3)


def test_batch_reps_respect_patience() raises:
    var calls = 0

    def count_call() raises {mut calls}:
        calls += 1

    var tester = RepetitionTester(
        RepetitionInstrument(),
        patience=3,
        batch_reps=2,
        max_reps=None,
    )

    var results = tester.run(count_call)
    assert_equal(calls, 5)
    assert_equal(results.test_count, 5)


def test_function_error_does_not_poison_tester() raises:
    var tester = RepetitionTester(RepetitionInstrument())

    with assert_raises(contains="test failure"):
        _ = tester.run(fail)

    # The instrument remains usable after the function propagates an error.
    with assert_raises(contains="test failure"):
        _ = tester.run(fail)


def test_table_renders_each_metric_component() raises:
    var tester = RepetitionTester(
        RepetitionInstrument(),
        patience=1,
        max_reps=2,
    )

    var results = tester.run(do_nothing)
    var table = _repetition_table(results)
    assert_equal(table.num_columns(), 3)
    assert_equal(table.column(0).header, "Statistic")
    assert_equal(table.column(1).header, "cycles")
    assert_equal(table.column(2).header, "instructions")

    var text = String(table)
    assert_equal(text.find("Repetition results — 2 repetitions") >= 0, True)
    assert_equal(text.find("Minimum") >= 0, True)
    assert_equal(text.find("Maximum") >= 0, True)
    assert_equal(text.find("Average") >= 0, True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
