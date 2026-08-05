from std.sys import size_of
from std.testing import assert_equal, assert_true, TestSuite

from professor import (
    Count,
    CountUnit,
    Memory,
    MemoryUnit,
    MetricDimension,
    Time,
    TimeUnit,
    Throughput,
)


def test_units_are_compile_time_only() raises:
    assert_equal(size_of[Time[TimeUnit.NANOS]](), size_of[Int]())
    assert_equal(size_of[Time[TimeUnit.SECONDS]](), size_of[Int]())
    assert_equal(size_of[Count["instructions"]](), size_of[Int]())
    assert_equal(size_of[Memory[]](), size_of[Int]())


def test_quantities_convert_from_their_storage_unit() raises:
    var elapsed = Time[TimeUnit.NANOS](1_500_000_000)
    assert_equal(elapsed.in_unit[TimeUnit.SECONDS](), 1.5)

    var instructions = Count["instructions", CountUnit.MILLION](3)
    assert_equal(instructions.in_unit[CountUnit.SINGLE](), 3_000_000.0)

    var memory = Memory[MemoryUnit.MEGABYTE](2)
    assert_equal(memory.in_unit[MemoryUnit.BYTE](), 2_000_000.0)


def test_metric_fields_erase_units_only_for_reporting() raises:
    var time_field = Time[TimeUnit.MICROS](25).fields()[0].copy()
    assert_true(time_field.unit)
    assert_true(time_field.unit.value().dimension == MetricDimension.TIME)
    assert_equal(time_field.unit.value().scale, 1_000.0)

    var count_field = Count["page-faults"](7).fields()[0].copy()
    assert_equal(count_field.name, "page-faults")
    assert_true(count_field.unit)
    assert_true(count_field.unit.value().dimension == MetricDimension.COUNT)


def test_throughput_converts_and_formats_after_measurement() raises:
    var throughput = Throughput(Memory[](2_000_000_000), 1_000_000_000.0)
    var rate = throughput.in_units(MemoryUnit.GIGABYTE, TimeUnit.SECONDS)
    assert_true(rate)
    assert_equal(rate.value(), 2.0)
    assert_equal(String(throughput), "2.0 GB/s")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
