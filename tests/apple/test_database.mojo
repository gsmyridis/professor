from std.testing import (
    assert_equal,
    assert_raises,
    assert_true,
)
from std.testing import TestSuite
from std.sys import CompilationTarget

from professor.apple import AppleEvent, Architecture, Database, Cpu


def test_database_create() raises:
    _ = Database()


def test_database_name() raises:
    var db = Database()

    var name = db.name()
    comptime if CompilationTarget.is_apple_m1():
        assert_equal(name, "a14", "unexpected database name:" + name)
    comptime if CompilationTarget.is_apple_m2():
        assert_equal(name, "a15", "unexpected database name:" + name)
    comptime if CompilationTarget.is_apple_m3():
        assert_true(
            name == "a16" or name == "as1" or name == "as2" or name == "as3",
            "unexpected database name:" + name,
        )
    comptime if CompilationTarget.is_apple_m4():
        assert_true(
            name == "as4" or name == "as4-1" or name == "as4-2",
            "unexpected database name:" + name,
        )
    comptime if CompilationTarget.is_apple_m5():
        assert_true(
            name == "as5" or name == "as5-2", "unexpected database name:" + name
        )


def test_database_marketing_name() raises:
    var db = Database()

    var name = db.marketing_name()
    comptime if CompilationTarget.is_apple_m1():
        assert_equal(name, "Apple A14/M1")
    elif CompilationTarget.is_apple_m2():
        assert_equal(name, "Apple A15")
    elif CompilationTarget.is_apple_m3():
        assert_equal(name, "Apple A16")
    elif CompilationTarget.is_apple_m4() or CompilationTarget.is_apple_m5():
        assert_equal(name, "Apple silicon")
    else:
        assert_true(False, "New apple model not supported yet")


def test_database_architecture() raises:
    var db = Database()

    if CompilationTarget.is_apple_silicon():
        assert_equal(
            db.architecture(),
            materialize[Architecture.Arm64](),
        )


# TODO: This is not a good test.
def test_database_event_count_matches_alias_count_sanity() raises:
    var db = Database()
    assert_true(db.event_count() > 0)
    assert_true(db.alias_count() >= 0)


def test_database_aliases_length_matches_alias_count() raises:
    var db = Database()
    assert_equal(len(db.aliases()), db.alias_count())


def test_database_events_length_matches_event_count() raises:
    var db = Database()
    var events = db.events()
    assert_equal(len(events), db.event_count())


# TODO: Check if the names are valid, not just empty
def test_database_events_have_nonempty_names() raises:
    var db = Database()
    var events = db.events()
    for i in range(len(events)):
        assert_true(events[i].name().count_codepoints() > 0)


def test_database_get_event_roundtrip() raises:
    # `InstAll` is available on every Apple Silicon generation, so this
    # doesn't depend on which chip the test runs on.
    var db = Database()
    var ev = db.get_event(AppleEvent.InstAll)
    assert_equal(String(ev.name()), "INST_ALL")


def test_database_get_event_missing_raises() raises:
    """`get_event` now takes an `AppleEvent`, resolved against the database's
    `Cpu` generation, instead of a raw, unchecked `StringSlice`: every name
    it ever passes to the C lookup comes from a compile-time string literal,
    so there's no longer an unsafe "arbitrary slice" input to misuse.

    `ArmBrMisPred` is M4/M5-only, so it raises on earlier generations. M4 and
    M5 have no gaps in `AppleEvent`'s coverage, so skip there.
    """
    var db = Database()
    var cpu = db.cpu()
    if cpu == Cpu.M4 or cpu == Cpu.M5:
        return

    with assert_raises(contains="unavailable"):
        _ = db.get_event(AppleEvent.ArmBrMisPred)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
