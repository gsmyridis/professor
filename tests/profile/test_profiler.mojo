from std.testing import assert_equal, assert_raises, assert_true, TestSuite

from professor import GlobalProfiler, Instrument, Nanos, Profiler, ReportColumn


# A deterministic measurer: each `measure()` returns a monotonically
# increasing tick, so durations are exact and independent of the wall clock.
# GlobalProfiler state is created lazily per `Tag` with a default-constructed
# measurer, so every test uses its own tag to get a fresh Ticker at 0.
struct Ticker(Instrument):
    comptime MetricType = Nanos
    var now: UInt64

    def __init__(out self):
        self.now = 0

    def measure(mut self) -> Nanos:
        self.now += 1
        return Nanos(self.now)


struct ConfigurableTicker(Instrument):
    comptime MetricType = Nanos
    var now: UInt64
    var step: UInt64

    def __init__(out self):
        self = Self(1)

    def __init__(out self, step: UInt64):
        self.now = 0
        self.step = step

    def measure(mut self) -> Nanos:
        self.now += self.step
        return Nanos(self.now)


def testis_profiling_enabled() raises:
    comptime assert Profiler[Ticker].is_enabled()
    comptime assert GlobalProfiler[Ticker, Tag="test.enabled"].is_enabled()


def test_runtime_profiler_owns_configured_instrument() raises:
    var prof = Profiler[ConfigurableTicker](ConfigurableTicker(5))

    prof.start()
    with prof.zone["runtime"]():
        pass
    prof.end()

    var report = prof.report()
    assert_equal(report.total.value, 15)
    assert_equal(report.stats[0].inclusive.value, 5)


def test_runtime_profilers_of_same_type_are_independent() raises:
    var fast = Profiler[ConfigurableTicker](ConfigurableTicker(1))
    var slow = Profiler[ConfigurableTicker](ConfigurableTicker(10))

    fast.start()
    with fast.zone["work"]():
        pass
    fast.end()

    slow.start()
    with slow.zone["work"]():
        pass
    slow.end()

    assert_equal(fast.report().total.value, 3)
    assert_equal(slow.report().total.value, 30)


def test_single_zone_inclusive_equals_exclusive() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.single"]

    Prof.start()  # tick 1
    var z = Prof.zone["only"]()  # tick 2
    z^.close()  # tick 3
    Prof.end()  # tick 4

    var rep = Prof.report()
    assert_equal(rep.total.value, 3)
    assert_equal(len(rep.stats), 1)
    assert_true(rep.stats[0].name == "only")
    assert_equal(rep.stats[0].count, 1)
    assert_equal(rep.stats[0].inclusive.value, 1)  # 2 - 1
    assert_equal(rep.stats[0].exclusive.value, 1)  # no children
    assert_equal(rep.stats[0].inclusive_min.value, 1)
    assert_true(rep.stats[0].loc.line() > 0)
    assert_true(rep.stats[0].loc.column() > 0)
    assert_true(
        String(rep.stats[0].loc.file_name()).endswith(
            "tests/profile/test_profiler.mojo"
        )
    )

    var table = String(rep)
    assert_true(table.find(ReportColumn.Zone.name()) != -1)
    assert_true(table.find(ReportColumn.Site.name()) != -1)
    assert_true(table.find(ReportColumn.Count.name()) != -1)
    assert_true(table.find(ReportColumn.Inclusive.name()) != -1)
    assert_true(table.find(ReportColumn.Exclusive.name()) != -1)
    assert_true(table.find(ReportColumn.InclusiveMin.name()) != -1)
    assert_true(table.find(ReportColumn.InclusiveAverage.name()) != -1)
    assert_true(table.find(ReportColumn.InclusivePercentage.name()) != -1)
    assert_true(table.find(ReportColumn.ExclusivePercentage.name()) != -1)
    assert_true(table.find("Program total: 3 ns") != -1)
    assert_true(table.find("tests/profile/test_profiler.mojo:") != -1)
    assert_true(table.find("only") != -1)
    assert_true(table.find("Inclusive (ns)") != -1)
    assert_true(table.find("33.3%") != -1)


def test_nested_exclusive_subtracts_child() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.nested"]

    Prof.start()
    var outer = Prof.zone["outer"]()
    var inner = Prof.zone["inner"]()
    inner^.close()
    outer^.close()
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.stats), 2)

    # Outer spans three ticks and inner spans one.
    var outer_incl = UInt64(0)
    var outer_excl = UInt64(0)
    var inner_incl = UInt64(0)
    for ref z in rep.stats:
        if z.name == "outer":
            outer_incl = z.inclusive.value
            outer_excl = z.exclusive.value
            assert_equal(z.inclusive_min.value, 3)
        elif z.name == "inner":
            inner_incl = z.inclusive.value
            assert_equal(z.inclusive_min.value, 1)

    assert_equal(outer_incl, 3)
    assert_equal(inner_incl, 1)
    assert_equal(outer_excl, 2)  # 3 inclusive - 1 child


def test_multiple_children_subtracted() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.siblings"]

    Prof.start()
    var a = Prof.zone["a"]()
    var b = Prof.zone["b"]()
    b^.close()
    var c = Prof.zone["c"]()
    c^.close()
    a^.close()
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.stats), 3)
    # a spans five ticks and both children (one tick each) are subtracted.
    for ref z in rep.stats:
        if z.name == "a":
            assert_equal(z.inclusive.value, 5)
            assert_equal(z.exclusive.value, 3)  # 5 - 1 - 1
        else:
            assert_true(z.name == "b" or z.name == "c")
            assert_equal(z.inclusive.value, 1)
            assert_equal(z.exclusive.value, 1)


# def test_reentry_aggregates() raises:
#     comptime Prof = GlobalProfiler[Ticker, Tag="test.reentry"]

#     Prof.start()
#     for _ in range(3):
#         var z = Prof.zone["loop"]()
#         z^.close()
#     Prof.end()

#     var rep = Prof.report()
#     assert_equal(len(rep.stats), 1)
#     assert_equal(rep.stats[0].count, 3)
#     assert_equal(rep.stats[0].inclusive.value, 3)  # 1 tick each
#     var table = String(rep)
#     assert_true(table.find("Inclusive/Iter (ns)") != -1)
#     assert_true(table.find("42.9%") != -1)


def test_deep_lifo_nesting() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.lifo"]

    Prof.start()
    var z1 = Prof.zone["a"]()
    var z2 = Prof.zone["b"]()
    var z3 = Prof.zone["c"]()
    z3^.close()
    z2^.close()
    z1^.close()
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.stats), 3)
    # a spans 1..6 (=5), b spans 2..5 (=3), c spans 3..4 (=1); each zone's
    # exclusive time is inclusive minus its single child's inclusive.
    for ref z in rep.stats:
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


comptime RecProf = GlobalProfiler[Ticker, Tag="test.recursion"]


def _recurse(depth: Int):
    var z = RecProf.zone["rec"]()
    if depth > 1:
        _recurse(depth - 1)
    z^.close()


def test_recursive_zone_counts_outermost_span_once() raises:
    # All three entries hit the same call site, hence the same anchor.
    # The three recursive entries open and close around one another.
    RecProf.start()
    _recurse(3)
    RecProf.end()

    var rep = RecProf.report()
    assert_equal(len(rep.stats), 1)
    assert_true(rep.stats[0].name == "rec")
    assert_equal(rep.stats[0].count, 3)
    # Inclusive spans only the outermost entry (1..6), not the sum of the
    # nested spans; self-nesting must not double count.
    assert_equal(rep.stats[0].inclusive.value, 5)
    # Inner deltas are added to the anchor and subtracted from it again as
    # their own parent, so exclusive also equals the outermost span.
    assert_equal(rep.stats[0].exclusive.value, 5)


def test_same_name_at_distinct_locations_creates_distinct_sites() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.same-name-locations"]

    Prof.start()
    # Source location is part of site identity, so these are separate anchors.
    var outer = Prof.zone["work"]()
    var inner = Prof.zone["work"]()
    inner^.close()  # elapsed 1
    outer^.close()  # elapsed 3
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.stats), 2)
    var inclusive_sum = UInt64(0)
    var exclusive_sum = UInt64(0)
    for ref stat in rep.stats:
        assert_true(stat.name == "work")
        assert_equal(stat.count, 1)
        inclusive_sum += stat.inclusive.value
        exclusive_sum += stat.exclusive.value
    assert_equal(inclusive_sum, 4)  # outer 3 + inner 1
    assert_equal(exclusive_sum, 3)  # outer self 2 + inner self 1


comptime ManualProf = GlobalProfiler[Ticker, Tag="test.manual-shared"]


def _hit_pinned_anchor():
    var z = ManualProf.zone["pinned", 0]()
    z^.close()


def test_manual_index_shares_anchor_across_call_sites() raises:
    # Pinning the anchor index bypasses call-site resolution, so two
    # different call sites with the same index aggregate into one anchor.
    ManualProf.start()
    _hit_pinned_anchor()
    var z = ManualProf.zone["pinned", 0]()
    z^.close()
    ManualProf.end()

    var rep = ManualProf.report()
    assert_equal(len(rep.stats), 1)
    assert_true(rep.stats[0].name == "pinned")
    assert_equal(rep.stats[0].count, 2)
    assert_equal(rep.stats[0].inclusive.value, 2)
    assert_equal(rep.stats[0].exclusive.value, 2)


def test_manual_and_automatic_anchors_coexist() raises:
    # Manual indices live in [0, Capacity); automatic sites are allocated
    # above them, so index 3 (the highest valid one here) cannot collide
    # with the runtime-resolved site.
    comptime Prof = GlobalProfiler[Ticker, Tag="test.capacity", Capacity=4]

    Prof.start()
    var auto_zone = Prof.zone["auto"]()
    auto_zone^.close()
    var manual_zone = Prof.zone["manual", 3]()
    manual_zone^.close()
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.stats), 2)
    for ref stat in rep.stats:
        assert_true(stat.name == "auto" or stat.name == "manual")
        assert_equal(stat.count, 1)
        assert_equal(stat.inclusive.value, 1)


def test_report_with_open_zone_raises() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.open"]

    # Can't use `with assert_raises(...)` here: its throw paths would abandon
    # the linear `z`. Catch everything, close `z`, then assert.
    Prof.start()
    var z = Prof.zone["open"]()
    var raised = False
    var end_raised = False
    try:
        _ = Prof.report()
    except err:
        raised = String(err).find("still open") != -1
    try:
        Prof.end()
    except err:
        end_raised = String(err).find("still open") != -1
    z^.close()
    Prof.end()
    assert_true(raised)
    assert_true(end_raised)


def test_session_lifecycle_errors_are_reported() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.lifecycle-errors"]

    with assert_raises(contains="before start"):
        Prof.end()
    with assert_raises(contains="before end"):
        _ = Prof.report()

    Prof.start()
    with assert_raises(contains="more than once"):
        Prof.start()
    Prof.end()
    with assert_raises(contains="more than once"):
        Prof.end()


comptime ResetProf = GlobalProfiler[Ticker, Tag="test.reset"]


def _record_reset_zone():
    with ResetProf.zone["reused"]():
        pass


def test_reset_starts_a_fresh_session_and_preserves_sites() raises:
    ResetProf.start()
    _record_reset_zone()
    ResetProf.end()
    assert_equal(ResetProf.report().stats[0].count, 1)

    ResetProf.reset()
    with assert_raises(contains="before end"):
        _ = ResetProf.report()

    ResetProf.start()
    _record_reset_zone()
    ResetProf.end()

    var report = ResetProf.report()
    assert_equal(len(report.stats), 1)
    assert_true(report.stats[0].name == "reused")
    assert_equal(report.stats[0].count, 1)


def test_reset_rejects_an_active_session() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.reset-active"]

    Prof.start()
    var raised = False
    try:
        Prof.reset()
    except error:
        raised = String(error).find("before end") != -1
    assert_true(raised)
    Prof.end()
    Prof.reset()


def test_report_is_repeatable() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.repeat"]

    Prof.start()
    var z = Prof.zone["once"]()
    z^.close()
    Prof.end()

    # report() only derives statistics; it must not consume or mutate them.
    var first = Prof.report()
    var second = Prof.report()
    assert_equal(len(first.stats), len(second.stats))
    assert_equal(first.stats[0].count, second.stats[0].count)
    assert_equal(
        first.stats[0].inclusive.value, second.stats[0].inclusive.value
    )


def test_with_statement_closes_zone() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.with"]

    Prof.start()
    with Prof.zone["scoped"]():
        pass
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.stats), 1)
    assert_true(rep.stats[0].name == "scoped")
    assert_equal(rep.stats[0].count, 1)
    assert_equal(rep.stats[0].inclusive.value, 1)


def test_with_statement_nests_with_linear_zones() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.with-nested"]

    Prof.start()
    with Prof.zone["outer"]():
        var inner = Prof.zone["inner"]()
        inner^.close()
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.stats), 2)
    for ref z in rep.stats:
        if z.name == "outer":
            assert_equal(z.inclusive.value, 3)
            assert_equal(z.exclusive.value, 2)  # 3 - 1 child
        else:
            assert_true(z.name == "inner")
            assert_equal(z.inclusive.value, 1)


def test_with_statement_closes_zone_on_raise() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.with-raise"]

    Prof.start()
    # Unlike a linear handle, a with-scoped zone closes itself on the unwind
    # path, so `assert_raises` cannot abandon it.
    with assert_raises(contains="boom"):
        with Prof.zone["failing"]():
            raise Error("boom")  # __exit__ closes while unwinding
    Prof.end()

    # The zone must be closed, so report() succeeds and counted the hit.
    var rep = Prof.report()
    assert_equal(len(rep.stats), 1)
    assert_equal(rep.stats[0].count, 1)
    assert_equal(rep.stats[0].inclusive.value, 1)


def test_byte_tracking_aggregates_reentered_zones() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.bytes-reentry"]

    Prof.start()
    for bytes in [UInt64(4), UInt64(6)]:
        with Prof.zone["work"](bytes=bytes):
            pass
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.stats), 1)
    assert_true(rep.stats[0].processed_data)
    assert_equal(rep.stats[0].processed_data.value().value, 10)
    assert_equal(rep.stats[0].inclusive.value, 2)

    var table = String(rep)
    assert_true(table.find("Throughput") != -1)
    assert_true(table.find("5") != -1)


def test_byte_tracking_accumulates_bytes_discovered_in_scope() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.bytes-incremental"]

    Prof.start()
    with Prof.zone["work"](bytes=UInt64(3)) as zone:
        zone.add_bytes(4)
        zone.add_bytes(5)
    Prof.end()

    var data = Prof.report().stats[0].processed_data
    assert_true(data)
    assert_equal(data.value().value, 12)


def test_directly_held_zone_accumulates_bytes() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.bytes-direct"]

    Prof.start()
    var zone = Prof.zone["work"](bytes=UInt64(3))
    zone.add_bytes(4)
    zone^.close()
    Prof.end()

    var data = Prof.report().stats[0].processed_data
    assert_true(data)
    assert_equal(data.value().value, 7)


comptime ByteRecProf = GlobalProfiler[Ticker, Tag="test.bytes-recursion"]


def _record_recursive_bytes(depth: Int, bytes: UInt64):
    var zone = ByteRecProf.zone["recursive"](bytes=bytes)
    if depth > 0:
        _record_recursive_bytes(depth - 1, bytes // 2)
    zone^.close()


def test_recursive_byte_tracking_sums_every_invocation() raises:
    ByteRecProf.start()
    _record_recursive_bytes(1, UInt64(100))
    ByteRecProf.end()

    var rep = ByteRecProf.report()
    assert_equal(len(rep.stats), 1)
    assert_equal(rep.stats[0].count, 2)
    assert_equal(rep.stats[0].inclusive.value, 3)
    assert_true(rep.stats[0].processed_data)
    assert_equal(rep.stats[0].processed_data.value().value, 150)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
