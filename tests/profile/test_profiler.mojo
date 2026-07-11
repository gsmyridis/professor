from std.testing import assert_equal, assert_true, TestSuite

from professor.profile import (
    Sample,
    Measurer,
    Nanos,
    Profiler,
    ProfileZone,
)


# A deterministic measurer: each `measure()` returns a monotonically
# increasing tick, so durations are exact and independent of the wall clock.
struct Ticker(Measurer):
    comptime S = Nanos
    var now: Int

    def __init__(out self):
        self.now = 0

    def measure(mut self) -> Nanos:
        self.now += 1
        return Nanos(self.now)


def test_single_zone_inclusive_equals_exclusive() raises:
    comptime Prof = Profiler[Ticker, "test.single"]
    Prof.install(Ticker())

    var z = Prof.zone["only"]()  # opens at tick 1
    z^.close()  # closes at tick 2

    var rep = Prof.report()
    assert_equal(len(rep.zones), 1)
    assert_true(rep.zones[0].name == "only")
    assert_equal(rep.zones[0].count, 1)
    assert_equal(rep.zones[0].inclusive.value, 1)  # 2 - 1
    assert_equal(rep.zones[0].exclusive.value, 1)  # no children
    assert_equal(rep.zones[0].min.value, 1)
    assert_equal(rep.zones[0].max.value, 1)
    assert_equal(rep.zones[0].mean.value, 1)
    assert_equal(rep.zones[0].variance.value, 0)
    Prof.reset()


def test_nested_exclusive_subtracts_child() raises:
    comptime Prof = Profiler[Ticker, "test.nested"]
    Prof.install(Ticker())

    var outer = Prof.zone["outer"]()  # tick 1
    var inner = Prof.zone["inner"]()  # tick 2
    inner^.close()  # tick 3
    outer^.close()  # tick 4

    var rep = Prof.report()
    assert_equal(len(rep.zones), 2)

    # Outer spans ticks 1..4 (=3), inner spans 2..3 (=1).
    var outer_incl = 0
    var outer_excl = 0
    var inner_incl = 0
    for ref z in rep.zones:
        if z.name == "outer":
            outer_incl = z.inclusive.value
            outer_excl = z.exclusive.value
        elif z.name == "inner":
            inner_incl = z.inclusive.value

    assert_equal(outer_incl, 3)
    assert_equal(inner_incl, 1)
    assert_equal(outer_excl, 2)  # 3 inclusive - 1 child
    Prof.reset()


def test_reentry_aggregates() raises:
    comptime Prof = Profiler[Ticker, "test.reentry"]
    Prof.install(Ticker())

    for _ in range(3):
        var z = Prof.zone["loop"]()
        z^.close()

    var rep = Prof.report()
    assert_equal(len(rep.zones), 1)
    assert_equal(rep.zones[0].count, 3)
    assert_equal(rep.zones[0].inclusive.value, 3)  # 1 tick each
    assert_equal(rep.zones[0].min.value, 1)
    assert_equal(rep.zones[0].max.value, 1)
    assert_equal(rep.zones[0].mean.value, 1)
    assert_equal(rep.zones[0].variance.value, 0)
    Prof.reset()


def test_deep_lifo_nesting() raises:
    comptime Prof = Profiler[Ticker, "test.lifo"]
    Prof.install(Ticker())

    var z1 = Prof.zone["a"]()  # tick 1
    var z2 = Prof.zone["b"]()  # tick 2
    var z3 = Prof.zone["c"]()  # tick 3
    z3^.close()  # tick 4
    z2^.close()  # tick 5
    z1^.close()  # tick 6

    var rep = Prof.report()
    assert_equal(len(rep.zones), 3)
    # a spans 1..6 (=5), b spans 2..5 (=3), c spans 3..4 (=1); each zone's
    # exclusive time is inclusive minus its single child's inclusive.
    for ref z in rep.zones:
        if z.name == "a":
            assert_equal(z.inclusive.value, 5)
            assert_equal(z.exclusive.value, 2)  # 5 - 3
        elif z.name == "b":
            assert_equal(z.inclusive.value, 3)
            assert_equal(z.exclusive.value, 2)  # 3 - 1
        else:
            assert_true(z.name == "c")
            assert_equal(z.inclusive.value, 1)
            assert_equal(z.exclusive.value, 1)  # innermost, no children
    Prof.reset()


def test_same_name_aggregates_without_double_count() raises:
    comptime Prof = Profiler[Ticker, "test.recursion"]
    Prof.install(Ticker())

    # Same name at two call sites: one logical site, as in a recursive
    # function entering its own zone.
    var outer = Prof.zone["work"]()  # tick 1
    var inner = Prof.zone["work"]()  # tick 2
    inner^.close()  # tick 3, elapsed 1
    outer^.close()  # tick 4, elapsed 3

    var rep = Prof.report()
    assert_equal(len(rep.zones), 1)  # one site, entered twice
    assert_equal(rep.zones[0].count, 2)
    # Inclusive spans only the outermost entry (3), not outer + inner (4).
    assert_equal(rep.zones[0].inclusive.value, 3)
    # All time is inside the site, so exclusive == inclusive.
    assert_equal(rep.zones[0].exclusive.value, 3)
    # Per-entry deltas are 1 and 3.
    assert_equal(rep.zones[0].min.value, 1)
    assert_equal(rep.zones[0].max.value, 3)
    assert_equal(rep.zones[0].mean.value, 2)  # (1 + 3) / 2
    assert_equal(rep.zones[0].variance.value, 1)  # (1 + 9)/2 - 2*2
    Prof.reset()


def test_report_with_open_zone_raises() raises:
    comptime Prof = Profiler[Ticker, "test.open"]
    Prof.install(Ticker())

    # Can't use `with assert_raises(...)` here: its throw paths would abandon
    # the linear `z`. Catch everything, close `z`, then assert.
    var z = Prof.zone["open"]()
    var raised = False
    try:
        _ = Prof.report()
    except err:
        raised = String(err).find("still open") != -1
    z^.close()
    assert_true(raised)
    Prof.reset()


def test_many_sites_grow_index() raises:
    # Force slot-table growth past the small install() reservation.
    comptime Prof = Profiler[Ticker, "test.growth"]
    Prof.install(Ticker(), sites=2)

    comptime for i in range(24):
        var z = Prof.zone[String(t"site{i}")]()
        z^.close()

    var rep = Prof.report()
    assert_equal(len(rep.zones), 24)
    for ref z in rep.zones:
        assert_equal(z.count, 1)
        assert_equal(z.inclusive.value, 1)
    Prof.reset()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
