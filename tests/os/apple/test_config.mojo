from std.testing import (
    assert_equal,
    assert_raises,
    assert_true,
)
from std.testing import TestSuite

from professor.os.apple import (
    ConfigBuilder,
    Database,
    AppleEvent,
    PortableEvent,
)


def test_config_create() raises:
    var db = Database()
    _ = ConfigBuilder(db)


def test_config_starts_with_no_events() raises:
    var db = Database()
    var cfg = ConfigBuilder(db)
    assert_equal(cfg.events_count(), 0)


def test_config_add_event() raises:
    var db = Database()
    var ev = db.get_event(AppleEvent.InstAll)
    var cfg = ConfigBuilder(db)
    cfg.force_counters()
    cfg.add_event(ev)

    assert_equal(cfg.events_count(), 1)
    var cfg_events = cfg.events()
    assert_equal(len(cfg_events), 1)
    assert_equal(String(cfg_events[0].name()), "INST_ALL")


def test_config_remove_event() raises:
    var db = Database()
    var ev = db.get_event(AppleEvent.InstAll)

    var cfg = ConfigBuilder(db)
    cfg.force_counters()
    cfg.add_event(ev)
    assert_equal(cfg.events_count(), 1)

    cfg.remove_event(0)
    assert_equal(cfg.events_count(), 0)


def test_config_remove_event_out_of_range_raises() raises:
    var db = Database()
    var cfg = ConfigBuilder(db)
    with assert_raises(contains="failed to remove event"):
        cfg.remove_event(0)


def test_config_counter_map_has_one_slot_per_event() raises:
    var db = Database()
    var cfg = ConfigBuilder(db)
    cfg.force_counters()
    cfg.add_event(db.get_event(PortableEvent.FixedCycles))
    cfg.add_event(db.get_event(PortableEvent.FixedInstructions))

    var counter_map = cfg.counter_map()
    assert_equal(len(counter_map), 2)
    assert_true(counter_map[0] >= 0)
    assert_true(counter_map[1] >= 0)


def test_config_build_returns_owned_configuration() raises:
    var db = Database()
    var cfg = ConfigBuilder(db)
    cfg.force_counters()
    cfg.add_event(db.get_event(PortableEvent.FixedCycles))
    cfg.add_event(db.get_event(PortableEvent.FixedInstructions))

    var configuration = cfg.build()
    assert_equal(configuration.classes, cfg.active_classes())
    assert_equal(len(configuration.counter_map), 2)
    assert_equal(len(configuration.event_names), 2)
    assert_equal(configuration.event_names[0], "FIXED_CYCLES")
    assert_equal(configuration.event_names[1], "FIXED_INSTRUCTIONS")
    assert_true(
        configuration.hardware_counter_count >= len(configuration.counter_map)
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
