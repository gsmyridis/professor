from std.testing import (
    assert_equal,
    assert_raises,
)
from std.testing import TestSuite

from professor.apple import Configuration, Database, AppleEvent


def test_config_create() raises:
    var db = Database()
    _ = Configuration(db)


def test_config_starts_with_no_events() raises:
    var db = Database()
    var cfg = Configuration(db)
    assert_equal(cfg.events_count(), 0)


def test_config_add_event() raises:
    var db = Database()
    var ev = db.get_event(AppleEvent.InstAll)
    var cfg = Configuration(db)
    cfg.force_counters()
    cfg.add_event(ev)

    assert_equal(cfg.events_count(), 1)
    var cfg_events = cfg.events()
    assert_equal(len(cfg_events), 1)
    assert_equal(String(cfg_events[0].name()), "INST_ALL")


def test_config_remove_event() raises:
    var db = Database()
    var ev = db.get_event(AppleEvent.InstAll)

    var cfg = Configuration(db)
    cfg.force_counters()
    cfg.add_event(ev)
    assert_equal(cfg.events_count(), 1)

    cfg.remove_event(0)
    assert_equal(cfg.events_count(), 0)


def test_config_remove_event_out_of_range_raises() raises:
    var db = Database()
    var cfg = Configuration(db)
    with assert_raises(contains="failed to remove event"):
        cfg.remove_event(0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
