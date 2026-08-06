from std.sys import size_of
from std.testing import assert_equal, TestSuite

from professor import (
    Count,
    CountUnit,
    DataSize,
    DataSizeUnit,
    TimestampCounter,
    Metric,
    Time,
    TimeUnit,
    Ticks,
)


@fieldwise_init
struct Perf(Metric):
    var elapsed: Time[TimeUnit.Micros]
    var instructions: Count["instructions", CountUnit.Million]
    var input: DataSize[DataSizeUnit.Kilobyte]


def test_quantities_convert_from_their_storage_unit() raises:
    var elapsed = Time[TimeUnit.Nanos](1_500_000_000)
    assert_equal(elapsed.in_unit[TimeUnit.Seconds](), 1.5)

    var instructions = Count["instructions", CountUnit.Million](3)
    assert_equal(instructions.in_unit[CountUnit.Single](), 3_000_000.0)

    var data = DataSize[DataSizeUnit.Megabyte](2)
    assert_equal(data.in_unit[DataSizeUnit.Byte](), 2_000_000.0)


def test_scalar_quantities_have_semantic_direct_output() raises:
    assert_equal(String(Time[TimeUnit.Micros](25)), "25us")
    assert_equal(String(Count["page-faults"](7)), "7page-faults")
    assert_equal(String(DataSize[DataSizeUnit.Megabyte](2)), "2MB")


def test_composite_metric_needs_only_field_declarations() raises:
    var zero = Perf()
    assert_equal(zero.elapsed.value, 0)
    assert_equal(zero.instructions.value, 0)
    assert_equal(zero.input.value, 0)

    var sample = Perf(
        Time[TimeUnit.Micros](25),
        Count["instructions", CountUnit.Million](3),
        DataSize[DataSizeUnit.Kilobyte](8),
    )
    assert_equal(sample.elapsed.value, 25)
    assert_equal(sample.instructions.value, 3)
    assert_equal(sample.input.value, 8)


def test_invariant_tsc_reports_timestamp_counter_ticks() raises:
    var instrument = TimestampCounter()
    var sample: Ticks = instrument.measure()
    _ = sample


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
