from std.ffi import _Global
from std.os import abort
from std.reflection import call_location, SourceLocation
from std.time import perf_counter_ns

from professor.measure import Sample, Measurer

# ===----------------------------------------------------------------------=== #
# Anchors and site resolution
# ===----------------------------------------------------------------------=== #


def _fnv1a(s: StaticString) -> UInt64:
    """FNV-1a over the name bytes. Evaluated at compile time for the comptime
    zone-name parameter, so the hot path never hashes a string at runtime."""
    var h: UInt64 = 0xCBF29CE484222325
    for b in s.as_bytes():
        h = (h ^ UInt64(Int(b))) * 0x100000001B3
    return h


struct _Anchor[S: Sample](Copyable):
    """Running statistics for one zone site, updated at every close.

    Memory is O(distinct sites), not O(zone entries): each close folds its
    elapsed delta into these accumulators, so no event log is kept and the
    anchor table stays small and cache-resident.

    `inclusive` is maintained with the overwrite trick (`inclusive at open +
    elapsed`) so recursive entries of the same site don't double-count.
    `exclusive` is signed accumulation: each close adds its own elapsed and
    subtracts it from its parent's anchor, so it can be transiently negative
    while zones are open (report() guards against observing that state).
    """

    var name: StaticString
    var loc: SourceLocation
    var hit_count: Int
    var inclusive: Self.S
    var exclusive: Self.S
    var sum: Self.S
    var sumsq: Self.S
    var min: Self.S
    var max: Self.S

    def __init__(out self, name: StaticString, loc: SourceLocation):
        self.name = name
        self.loc = loc
        self.hit_count = 0
        self.inclusive = Self.S()
        self.exclusive = Self.S()
        self.sum = Self.S()
        self.sumsq = Self.S()
        self.min = Self.S()
        self.max = Self.S()


@fieldwise_init
struct _SiteSlot(Copyable):
    """One open-addressing slot mapping a zone name to its anchor index.

    `idx < 0` marks an empty slot. Slots are never deleted individually, so
    linear probing needs no tombstones.
    """

    var hash: UInt64
    var name: StaticString
    var idx: Int


struct _State[M: Measurer](Movable):
    """Process-global profiler state.

    Holds the per-site anchor table, an open-addressed index from zone name to
    anchor (probed with a compile-time hash), the innermost open anchor
    (`current_open`, -1 at the root), and a stack of unique zone serials used
    to enforce LIFO nesting at close time -- anchor indices alone can't tell
    apart two open zones of the same site.
    """

    comptime SampleType = Self.M.S

    var measurer: Optional[Self.M]
    var anchors: List[_Anchor[Self.M.S]]
    var site_slots: List[_SiteSlot]
    var open_serials: List[Int]
    var current_open: Int
    var next_serial: Int

    def __init__(out self):
        self.measurer = None # TODO: Make Measurer Defaultable or thin closure
        self.anchors = List[_Anchor[Self.SampleType]]()
        self.site_slots = List[_SiteSlot]()
        self.open_serials = List[Int]()
        self.current_open = -1
        self.next_serial = 0

    @always_inline
    def _find_site(self, h: UInt64, name: StaticString) -> Int:
        """Probes for `name`, returning its anchor index or -1.

        The comptime name parameter makes the hash a constant and the pointer
        comparison almost always sufficient; the content comparison only runs
        on a pointer mismatch for an equal hash.
        """
        var cap = len(self.site_slots)
        if cap == 0:
            return -1
        var mask = cap - 1
        var i = Int(h & UInt64(mask))
        while True:
            ref slot = self.site_slots[i]
            if slot.idx < 0:
                return -1
            if slot.hash == h and (
                slot.name.unsafe_ptr() == name.unsafe_ptr()
                or slot.name == name
            ):
                return slot.idx
            i = (i + 1) & mask

    def _register_site(
        mut self, h: UInt64, name: StaticString, loc: SourceLocation
    ) -> Int:
        """Cold path: creates the anchor for a site on its first visit."""
        # Keep load factor under 3/4 so probes stay short.
        if (len(self.anchors) + 1) * 4 > len(self.site_slots) * 3:
            self._grow_slots()
        var idx = len(self.anchors)
        self.anchors.append(_Anchor[Self.M.S](name, loc))
        var mask = len(self.site_slots) - 1
        var i = Int(h & UInt64(mask))
        while self.site_slots[i].idx >= 0:
            i = (i + 1) & mask
        self.site_slots[i] = _SiteSlot(h, name, idx)
        return idx

    def _grow_slots(mut self):
        var new_cap = 16 if len(self.site_slots) == 0 else (
            len(self.site_slots) * 2
        )
        var fresh = List[_SiteSlot](capacity=new_cap)
        for _ in range(new_cap):
            fresh.append(_SiteSlot(0, "", -1))
        var mask = new_cap - 1
        for ref s in self.site_slots:
            if s.idx >= 0:
                var i = Int(s.hash & UInt64(mask))
                while fresh[i].idx >= 0:
                    i = (i + 1) & mask
                fresh[i] = s.copy()
        self.site_slots = fresh^


# ===----------------------------------------------------------------------=== #
# Profiler
# ===----------------------------------------------------------------------=== #


struct Profiler[M: Measurer, tag: StaticString = "professor.default"]:
    """Global orchestration handle for scoped profiling.

    Bind the measurer type once and drive it statically:

    ```mojo
    from professor.profile import Profiler
    from professor.measure.default import WallClock

    comptime Prof = Profiler[WallClock]

    Prof.install(WallClock())
    var z1 = Prof.zone["render"]()
    var z2 = Prof.zone["physics"]()
    ...
    z2^.close()
    z1^.close()
    print(Prof.report())
    ```

    All state lives in a process-global keyed by `tag`, so `zone()` works from
    anywhere in the call tree without threading a profiler object through every
    frame. Distinct measurer types in one process need distinct `tag`s.

    A zone site is identified by its comptime name (within a tag). The name's
    hash is computed at compile time, so entering a zone costs one O(1) table
    probe -- no string hashing or scanning. Opening a zone with the same name
    in several places deliberately aggregates them into one logical site; the
    recorded source location is where the site was first opened.

    Statistics are aggregated on every zone close into a fixed per-site anchor
    table (count, inclusive, exclusive, min, max, and the sums needed for mean
    and variance). Nothing is logged per entry, so memory stays O(sites) and
    the hot path never allocates after a site's first visit.

    Zones must be closed in strict LIFO order (innermost first); `close()`
    aborts otherwise. This is what makes exclusive (self) time well-defined:
    "self" means "inclusive minus contained children", which only exists when
    intervals nest.
    """

    comptime _global = _Global[Self.tag, Self._make]

    @staticmethod
    def _make() -> _State[Self.M]:
        return _State[Self.M]()

    @staticmethod
    def _state() -> UnsafePointer[_State[Self.M], MutUntrackedOrigin]:
        # A raising zone()/close() would leave enclosing @explicit_destroy
        # zones abandoned on the throw path, so state-init failure is fatal.
        try:
            return Self._global.get_or_create_ptr()
        except err:
            abort(String(t"failed to initialize profiler state: {err}"))

    @staticmethod
    def install(var measurer: Self.M, sites: Int = 128):
        """Registers the measurer and pre-reserves the anchor and index
        tables.

        `sites` is the expected number of distinct zone names. Exceeding it
        grows the tables when a new name is first seen -- a one-time cost per
        site, not per entry.
        """
        var st = Self._state()
        st[].measurer = measurer^
        st[].anchors = List[_Anchor[Self.M.S]](capacity=sites)
        var cap = 16
        while cap < sites * 2:
            cap *= 2
        st[].site_slots = List[_SiteSlot](capacity=cap)
        for _ in range(cap):
            st[].site_slots.append(_SiteSlot(0, "", -1))
        st[].open_serials = List[Int](capacity=64)
        st[].current_open = -1
        st[].next_serial = 0

    @always_inline
    @staticmethod
    def zone[name: StaticString]() -> ProfileZone[Self.M]:
        """Opens the zone `name`, recording the caller's source location on
        the site's first visit."""
        comptime h = _fnv1a(name)
        var st = Self._state()
        var idx = st[]._find_site(h, name)
        if idx < 0:
            idx = st[]._register_site(h, name, call_location())

        var parent = st[].current_open
        st[].current_open = idx
        var serial = st[].next_serial
        st[].next_serial += 1
        st[].open_serials.append(serial)
        var prev_inclusive = st[].anchors[idx].inclusive.copy()

        # Sample as late as possible so open-side bookkeeping stays out of the
        # measured interval.
        var s = st[].measurer.value().measure()
        return ProfileZone[Self.M](idx, parent, serial, prev_inclusive^, s^, st)

    @staticmethod
    def report() raises -> Report[Self.M.S]:
        """Derives per-site statistics from the anchor table.

        Raises if any zone is still open: exclusive times are transiently
        inconsistent (children already subtracted, parent not yet added), so
        a report taken now would be garbage.
        """
        var st = Self._state()
        var open_count = len(st[].open_serials)
        if open_count != 0:
            raise Error(
                String(t"report() called with {open_count} zone(s) still open")
            )
        var stats = List[ZoneStat[Self.M.S]](capacity=len(st[].anchors))
        for ref a in st[].anchors:
            if a.hit_count == 0:
                continue
            var mean = a.sum / a.hit_count
            var variance = a.sumsq / a.hit_count - mean * mean
            stats.append(
                ZoneStat[Self.M.S](
                    a.name,
                    a.loc,
                    a.hit_count,
                    a.inclusive.copy(),
                    a.exclusive.copy(),
                    a.min.copy(),
                    a.max.copy(),
                    mean^,
                    variance^,
                )
            )
        return Report[Self.M.S](stats^)

    @staticmethod
    def reset() raises:
        """Clears the anchor table for a fresh run. Raises if any zone is
        still open."""
        var st = Self._state()
        var open_count = len(st[].open_serials)
        if open_count != 0:
            raise Error(
                String(t"reset() called with {open_count} zone(s) still open")
            )
        st[].anchors.clear()
        for ref s in st[].site_slots:
            s.idx = -1
        st[].current_open = -1
        st[].next_serial = 0


@explicit_destroy(".close()")
struct ProfileZone[M: Measurer]:
    """A linear handle for an open profiling zone.

    ProfileZone is a linear type because, otherwise, the zone would close
    prematurely, since Mojo implements ASAP destruction for implicitly
    deletable types.

    Being `@explicit_destroy` makes the compiler prove every zone is eventually
    closed; `close()` additionally enforces that closes happen in LIFO order.
    The handle is movable, so it can escape its opening scope -- the LIFO check
    and `report()`'s open-zone guard exist to catch that misuse.
    """

    var anchor_idx: Int
    var parent_idx: Int
    var serial: Int
    var prev_inclusive: Self.M.S
    var opened: Self.M.S
    var st: UnsafePointer[_State[Self.M], MutUntrackedOrigin]

    def __init__(
        out self,
        anchor_idx: Int,
        parent_idx: Int,
        serial: Int,
        var prev_inclusive: Self.M.S,
        var opened: Self.M.S,
        st: UnsafePointer[_State[Self.M], MutUntrackedOrigin],
    ):
        self.anchor_idx = anchor_idx
        self.parent_idx = parent_idx
        self.serial = serial
        self.prev_inclusive = prev_inclusive^
        self.opened = opened^
        self.st = st

    @always_inline
    def close(deinit self):
        """Closes the zone and folds its elapsed delta into the site's anchor.
        Aborts unless this is the innermost open zone.

        Out-of-order closes are a programming error (they make exclusive time
        undefined), and a raising close would force try/except around every
        enclosing zone, so this aborts instead.
        """
        # Sample first so close-side bookkeeping stays out of the interval.
        var s = self.st[].measurer.value().measure()

        var n = len(self.st[].open_serials)
        if n == 0 or self.st[].open_serials[n - 1] != self.serial:
            var name = self.st[].anchors[self.anchor_idx].name
            var innermost: String
            if n == 0 or self.st[].current_open < 0:
                innermost = "none (no zones open)"
            else:
                innermost = String(
                    self.st[].anchors[self.st[].current_open].name
                )
            abort(
                String(
                    t"zone '{name}' closed out of order; innermost open zone is '{innermost}'"
                )
            )
        _ = self.st[].open_serials.pop()
        self.st[].current_open = self.parent_idx

        var e = s - self.opened

        ref a = self.st[].anchors[self.anchor_idx]
        if a.hit_count == 0:
            a.min = e.copy()
            a.max = e.copy()
        else:
            a.min = a.min.min(e)
            a.max = a.max.max(e)
        a.hit_count += 1
        # Overwrite, don't accumulate: under recursion the outermost close
        # lands last and its `prev + elapsed` already spans the inner entries.
        a.inclusive = self.prev_inclusive + e
        a.exclusive = a.exclusive + e
        a.sum = a.sum + e
        a.sumsq = a.sumsq + e * e

        if self.parent_idx >= 0:
            ref p = self.st[].anchors[self.parent_idx]
            p.exclusive = p.exclusive - e


# ===----------------------------------------------------------------------=== #
# Report
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct ZoneStat[S: Sample](Copyable, Movable):
    """Aggregated statistics for one zone site.

    `mean` and `variance` are per-close statistics of the inclusive elapsed
    delta (`variance` is in squared sample units). Under recursion, inner
    entries contribute their own deltas to count/min/max/mean/variance, while
    `inclusive` spans only the outermost entry. `loc` is where the site was
    first opened.
    """

    var name: StaticString
    var loc: SourceLocation
    var count: Int
    var inclusive: Self.S
    var exclusive: Self.S
    var min: Self.S
    var max: Self.S
    var mean: Self.S
    var variance: Self.S


struct Report[S: Sample](Writable):
    """The result of a profiling run: per-site statistics."""

    var zones: List[ZoneStat[Self.S]]

    def __init__(out self, var zones: List[ZoneStat[Self.S]]):
        self.zones = zones^

    def write_to(self, mut writer: Some[Writer]):
        for ref z in self.zones:
            writer.write(
                z.name,
                " (",
                z.loc,
                ")  count=",
                z.count,
                "  inclusive=",
                z.inclusive,
                "  exclusive=",
                z.exclusive,
                "  min=",
                z.min,
                "  max=",
                z.max,
                "  mean=",
                z.mean,
                "  variance=",
                z.variance,
                "\n",
            )
