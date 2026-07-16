from std.testing import assert_equal, assert_raises, assert_true, TestSuite

from professor import Instrument, Profiler, Nanos


# A deterministic measurer: each `measure()` returns a monotonically
# increasing tick, so durations are exact and independent of the wall clock.
# Profiler state is created lazily per `Tag` with a default-constructed
# measurer, so every test uses its own tag to get a fresh Ticker at 0.
struct Ticker(Instrument):
    comptime MetricType = Nanos
    var now: Int

    def __init__(out self):
        self.now = 0

    def measure(mut self) -> Nanos:
        self.now += 1
        return Nanos(self.now)


def test_single_zone_inclusive_equals_exclusive() raises:
    comptime Prof = Profiler[Ticker, Tag="test.single"]

    var z = Prof.zone["only"]()  # opens at tick 1
    z^.close()  # closes at tick 2

    var rep = Prof.report()
    assert_equal(len(rep.zones), 1)
    assert_true(rep.zones[0].name == "only")
    assert_equal(rep.zones[0].count, 1)
    assert_equal(rep.zones[0].inclusive.value, 1)  # 2 - 1
    assert_equal(rep.zones[0].exclusive.value, 1)  # no children


def test_nested_exclusive_subtracts_child() raises:
    comptime Prof = Profiler[Ticker, Tag="test.nested"]

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


def test_multiple_children_subtracted() raises:
    comptime Prof = Profiler[Ticker, Tag="test.siblings"]

    var a = Prof.zone["a"]()  # tick 1
    var b = Prof.zone["b"]()  # tick 2
    b^.close()  # tick 3
    var c = Prof.zone["c"]()  # tick 4
    c^.close()  # tick 5
    a^.close()  # tick 6

    var rep = Prof.report()
    assert_equal(len(rep.zones), 3)
    # a spans 1..6 (=5) and both children (1 tick each) are subtracted.
    for ref z in rep.zones:
        if z.name == "a":
            assert_equal(z.inclusive.value, 5)
            assert_equal(z.exclusive.value, 3)  # 5 - 1 - 1
        else:
            assert_true(z.name == "b" or z.name == "c")
            assert_equal(z.inclusive.value, 1)
            assert_equal(z.exclusive.value, 1)


def test_reentry_aggregates() raises:
    comptime Prof = Profiler[Ticker, Tag="test.reentry"]

    for _ in range(3):
        var z = Prof.zone["loop"]()
        z^.close()

    var rep = Prof.report()
    assert_equal(len(rep.zones), 1)
    assert_equal(rep.zones[0].count, 3)
    assert_equal(rep.zones[0].inclusive.value, 3)  # 1 tick each


def test_deep_lifo_nesting() raises:
    comptime Prof = Profiler[Ticker, Tag="test.lifo"]

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


comptime RecProf = Profiler[Ticker, Tag="test.recursion"]


def _recurse(depth: Int):
    var z = RecProf.zone["rec"]()
    if depth > 1:
        _recurse(depth - 1)
    z^.close()


def test_recursive_zone_counts_outermost_span_once() raises:
    # All three entries hit the same call site, hence the same anchor.
    # Opens at ticks 1, 2, 3; closes at 4, 5, 6.
    _recurse(3)

    var rep = RecProf.report()
    assert_equal(len(rep.zones), 1)
    assert_true(rep.zones[0].name == "rec")
    assert_equal(rep.zones[0].count, 3)
    # Inclusive spans only the outermost entry (1..6), not the sum of the
    # nested spans; self-nesting must not double count.
    assert_equal(rep.zones[0].inclusive.value, 5)
    # Inner deltas are added to the anchor and subtracted from it again as
    # their own parent, so exclusive also equals the outermost span.
    assert_equal(rep.zones[0].exclusive.value, 5)


def test_same_name_at_distinct_locations_creates_distinct_sites() raises:
    comptime Prof = Profiler[Ticker, Tag="test.same-name-locations"]

    # Source location is part of site identity, so these are separate anchors.
    var outer = Prof.zone["work"]()  # tick 1
    var inner = Prof.zone["work"]()  # tick 2
    inner^.close()  # tick 3, elapsed 1
    outer^.close()  # tick 4, elapsed 3

    var rep = Prof.report()
    assert_equal(len(rep.zones), 2)
    var inclusive_sum = 0
    var exclusive_sum = 0
    for ref stat in rep.zones:
        assert_true(stat.name == "work")
        assert_equal(stat.count, 1)
        inclusive_sum += stat.inclusive.value
        exclusive_sum += stat.exclusive.value
    assert_equal(inclusive_sum, 4)  # outer 3 + inner 1
    assert_equal(exclusive_sum, 3)  # outer self 2 + inner self 1


comptime ManualProf = Profiler[Ticker, Tag="test.manual-shared"]


def _hit_pinned_anchor():
    var z = ManualProf.zone["pinned", 0]()
    z^.close()


def test_manual_index_shares_anchor_across_call_sites() raises:
    # Pinning the anchor index bypasses call-site resolution, so two
    # different call sites with the same index aggregate into one anchor.
    _hit_pinned_anchor()  # ticks 1, 2
    var z = ManualProf.zone["pinned", 0]()  # tick 3
    z^.close()  # tick 4

    var rep = ManualProf.report()
    assert_equal(len(rep.zones), 1)
    assert_true(rep.zones[0].name == "pinned")
    assert_equal(rep.zones[0].count, 2)
    assert_equal(rep.zones[0].inclusive.value, 2)
    assert_equal(rep.zones[0].exclusive.value, 2)


def test_manual_and_automatic_anchors_coexist() raises:
    # Manual indices live in [0, Capacity); automatic sites are allocated
    # above them, so index 3 (the highest valid one here) cannot collide
    # with the runtime-resolved site.
    comptime Prof = Profiler[Ticker, Tag="test.capacity", Capacity=4]

    var auto_zone = Prof.zone["auto"]()  # tick 1
    auto_zone^.close()  # tick 2
    var manual_zone = Prof.zone["manual", 3]()  # tick 3
    manual_zone^.close()  # tick 4

    var rep = Prof.report()
    assert_equal(len(rep.zones), 2)
    for ref stat in rep.zones:
        assert_true(stat.name == "auto" or stat.name == "manual")
        assert_equal(stat.count, 1)
        assert_equal(stat.inclusive.value, 1)


def test_report_with_open_zone_raises() raises:
    comptime Prof = Profiler[Ticker, Tag="test.open"]

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


def test_report_is_repeatable() raises:
    comptime Prof = Profiler[Ticker, Tag="test.repeat"]

    var z = Prof.zone["once"]()
    z^.close()

    # report() only derives statistics; it must not consume or mutate them.
    var first = Prof.report()
    var second = Prof.report()
    assert_equal(len(first.zones), len(second.zones))
    assert_equal(first.zones[0].count, second.zones[0].count)
    assert_equal(
        first.zones[0].inclusive.value, second.zones[0].inclusive.value
    )


def test_with_statement_closes_zone() raises:
    comptime Prof = Profiler[Ticker, Tag="test.with"]

    with Prof.zone["scoped"]():  # opens at tick 1, closes at tick 2
        pass

    var rep = Prof.report()
    assert_equal(len(rep.zones), 1)
    assert_true(rep.zones[0].name == "scoped")
    assert_equal(rep.zones[0].count, 1)
    assert_equal(rep.zones[0].inclusive.value, 1)


def test_with_statement_nests_with_linear_zones() raises:
    comptime Prof = Profiler[Ticker, Tag="test.with-nested"]

    with Prof.zone["outer"]():  # tick 1
        var inner = Prof.zone["inner"]()  # tick 2
        inner^.close()  # tick 3
        # outer closes at tick 4

    var rep = Prof.report()
    assert_equal(len(rep.zones), 2)
    for ref z in rep.zones:
        if z.name == "outer":
            assert_equal(z.inclusive.value, 3)
            assert_equal(z.exclusive.value, 2)  # 3 - 1 child
        else:
            assert_true(z.name == "inner")
            assert_equal(z.inclusive.value, 1)


def test_with_statement_closes_zone_on_raise() raises:
    comptime Prof = Profiler[Ticker, Tag="test.with-raise"]

    # Unlike a linear handle, a with-scoped zone closes itself on the unwind
    # path, so `assert_raises` cannot abandon it.
    with assert_raises(contains="boom"):
        with Prof.zone["failing"]():  # tick 1
            raise Error("boom")  # __exit__ closes at tick 2 while unwinding

    # The zone must be closed, so report() succeeds and counted the hit.
    var rep = Prof.report()
    assert_equal(len(rep.zones), 1)
    assert_equal(rep.zones[0].count, 1)
    assert_equal(rep.zones[0].inclusive.value, 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
