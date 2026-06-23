from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    assert_not_equal,
)
from std.testing import TestSuite
from std.sys import CompilationTarget

from professor.apple import kperf_data
from professor.apple.events import KnownEvent
from professor.apple.cpu import Cpu


def test_config_create() raises:
    var db = kperf_data.Database()
    _ = kperf_data.Config(db)


def test_config_starts_with_no_events() raises:
    var db = kperf_data.Database()
    var cfg = kperf_data.Config(db)
    assert_equal(cfg.events_count(), 0)


def test_config_add_event() raises:
    var db = kperf_data.Database()
    var ev = db.get_event(KnownEvent.InstAll)
    var cfg = kperf_data.Config(db)
    cfg.force_counters()
    cfg.add_event(ev)

    assert_equal(cfg.events_count(), 1)
    var cfg_events = cfg.events()
    assert_equal(len(cfg_events), 1)
    assert_equal(String(cfg_events[0].name()), "INST_ALL")


def test_config_remove_event() raises:
    var db = kperf_data.Database()
    var ev = db.get_event(KnownEvent.InstAll)

    var cfg = kperf_data.Config(db)
    cfg.force_counters()
    cfg.add_event(ev)
    assert_equal(cfg.events_count(), 1)

    cfg.remove_event(0)
    assert_equal(cfg.events_count(), 0)


def test_config_remove_event_out_of_range_raises() raises:
    var db = kperf_data.Database()
    var cfg = kperf_data.Config(db)
    with assert_raises(contains="failed to remove event"):
        cfg.remove_event(0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
