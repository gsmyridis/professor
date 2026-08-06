from std.sys import size_of
from std.testing import assert_equal, TestSuite

from professor import (
    GlobalProfiler,
    Instrument,
    Nanos,
    Profiler,
)


struct PassiveInstrument(Instrument):
    comptime MetricType = Nanos

    def __init__(out self):
        pass

    def measure(mut self) -> Nanos:
        return Nanos(999)


def test_runtime_profiler_is_a_noop() raises:
    comptime assert not Profiler[PassiveInstrument].is_enabled()
    assert_equal(size_of[Profiler[PassiveInstrument]](), 0)
    var profiler = Profiler[PassiveInstrument]()

    # Disabled lifecycle calls neither enforce session state nor sample.
    profiler.end()
    profiler.start()
    profiler.start()
    profiler.reset()
    profiler.end()

    # Both zone forms are valid even outside a profiling session.
    with profiler.zone["scoped"]():
        pass
    with profiler.zone["bytes"](bytes=UInt64(1024)) as zone:
        zone.add_bytes(512)
    var zone = profiler.zone["manual", 0]()
    zone^.close()
    var byte_zone = profiler.zone["manual-bytes", 1](bytes=UInt64(2048))
    comptime assert size_of[type_of(byte_zone)]() == 0
    byte_zone^.close()

    var report = profiler.report()
    assert_equal(report.total.value, 0)
    assert_equal(len(report.stats), 0)
    assert_equal(len(report.tables()), 0)


def test_global_profiler_does_not_create_measurements() raises:
    comptime Prof = GlobalProfiler[PassiveInstrument, Tag="test.disabled"]
    comptime assert not Prof.is_enabled()

    Prof.end()
    Prof.start()
    with Prof.zone["scoped"]():
        pass
    with Prof.zone["bytes"](bytes=UInt64(1024)) as zone:
        zone.add_bytes(512)
    var zone = Prof.zone["manual", 0]()
    comptime assert size_of[type_of(zone)]() == 0
    zone^.close()
    Prof.reset()

    var report = Prof.report()
    assert_equal(report.total.value, 0)
    assert_equal(len(report.stats), 0)
    assert_equal(len(report.tables()), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
