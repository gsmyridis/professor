from std.ffi import _Global
from std.collections import Dict
from std.hashlib import default_comp_time_hasher, Hasher
from std.os import abort
from std.reflection import call_location, SourceLocation

from professor.measure import Sample, Measurer
from .report import Report, ZoneStat

# ===----------------------------------------------------------------------=== #
# Anchors
# ===----------------------------------------------------------------------=== #


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

# ===----------------------------------------------------------------------=== #
# Call site key
# ===----------------------------------------------------------------------=== #

@always_inline
def _site_hash(name_hash: UInt64, loc: SourceLocation) -> UInt64:
    """Mixes the cheap numeric portion of a source location into a comptime
    name hash. The file name remains part of the equality check."""
    var h = (name_hash ^ UInt64(loc.line())) * 0x100000001B3
    return (h ^ UInt64(loc.column())) * 0x100000001B3


@fieldwise_init
struct _SiteKey(Copyable, Equatable, Hashable, Movable):
    """Complete site identity with a cheaply hashable fingerprint."""

    var fingerprint: UInt64
    var name: StaticString
    var file: StaticString
    var line: Int
    var column: Int

    @always_inline
    def __hash__(self, mut hasher: Some[Hasher]):
        hasher.update(self.fingerprint)

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        return (
            self.fingerprint == other.fingerprint
            and self.line == other.line
            and self.column == other.column
            and _same_static_string(self.name, other.name)
            and _same_static_string(self.file, other.file)
        )


comptime _SiteDict = Dict[_SiteKey, Int, default_comp_time_hasher]


struct _State[M: Measurer](Movable):
    """Process-global profiler state.

    Holds dense per-site anchors, a standard dictionary from site identity to
    anchor index, the innermost open anchor (`current_open`, -1 at the root),
    and a nesting depth used to enforce LIFO close order.
    """

    comptime SampleType = Self.M.S

    var measurer: Optional[Self.M]
    var anchors: List[_Anchor[Self.M.S]]
    var sites: _SiteDict
    var current_open: Int
    var open_depth: Int

    def __init__(out self):
        self.measurer = None  # TODO: Make Measurer Defaultable or thin closure
        self.anchors = List[_Anchor[Self.SampleType]]()
        self.sites = _SiteDict()
        self.current_open = -1
        self.open_depth = 0

    def _resolve_site(mut self, var key: _SiteKey) -> Int:
        """Returns the site's dense anchor index, registering it on first use.
        """
        var existing = self.sites.get(key)
        if existing:
            return existing.value()

        var idx = len(self.anchors)
        var loc = SourceLocation(key.line, key.column, key.file)
        self.anchors.append(_Anchor[Self.M.S](key.name, loc))
        self.sites[key^] = idx
        return idx


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

    A zone site is identified by its comptime name and source location (within a
    tag). Sites register lazily in a standard `Dict` on first execution, so code
    in any module can instrument itself without central registration. Same-name
    zones at different call sites remain distinct.

    Statistics are aggregated on every zone close into a dense per-site anchor
    list (count, inclusive, exclusive, min, max, and the sums needed for mean
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
        """Registers the measurer and pre-reserves anchors and the site registry.

        `sites` is the expected number of distinct zone sites. Exceeding it
        grows the tables when a new name is first seen -- a one-time cost per
        site, not per entry.
        """
        var st = Self._state()
        var expected_sites = sites
        if expected_sites < len(st[].anchors):
            expected_sites = len(st[].anchors)
        st[].measurer = measurer^
        st[].anchors.reserve(expected_sites)
        if len(st[].sites) == 0:
            st[].sites = _SiteDict(capacity=expected_sites)
        st[].anchors = []
        st[].current_open = -1
        st[].open_depth = 0

    @always_inline
    @staticmethod
    def zone[name: StaticString]() -> ProfileZone[Self.M]:
        """Opens the zone `name`, recording the caller's source location on
        the site's first visit."""
        comptime name_hash = _hash_comp_time(name)
        var loc = call_location()
        var st = Self._state()
        var h = _site_hash(name_hash, loc)
        var key = _SiteKey(h, name, loc.file_name(), loc.line(), loc.column())
        var idx = st[]._resolve_site(key^)
        return _open_zone(st, idx)

    @staticmethod
    def report() raises -> Report[Self.M.S]:
        """Derives per-site statistics from the anchor table.

        Raises if any zone is still open: exclusive times are transiently
        inconsistent (children already subtracted, parent not yet added), so
        a report taken now would be garbage.
        """
        var st = Self._state()
        var open_count = st[].open_depth
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


@always_inline
def _open_zone[
    M: Measurer
](st: UnsafePointer[_State[M], MutUntrackedOrigin], idx: Int) -> ProfileZone[M]:
    var parent = st[].current_open
    var depth = st[].open_depth
    st[].current_open = idx
    st[].open_depth = depth + 1
    var prev_inclusive = st[].anchors[idx].inclusive.copy()

    # Sample as late as possible so open-side bookkeeping stays out of the
    # measured interval.
    var sample = st[].measurer.value().measure()
    return ProfileZone[M](idx, parent, depth, prev_inclusive^, sample^, st)


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
    var depth: Int
    var prev_inclusive: Self.M.S
    var opened: Self.M.S
    var st: UnsafePointer[_State[Self.M], MutUntrackedOrigin]

    def __init__(
        out self,
        anchor_idx: Int,
        parent_idx: Int,
        depth: Int,
        var prev_inclusive: Self.M.S,
        var opened: Self.M.S,
        st: UnsafePointer[_State[Self.M], MutUntrackedOrigin],
    ):
        self.anchor_idx = anchor_idx
        self.parent_idx = parent_idx
        self.depth = depth
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

        var n = self.st[].open_depth
        if n != self.depth + 1:
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
                    t"zone '{name}' closed out of order; innermost open zone is"
                    t" '{innermost}'"
                )
            )
        self.st[].open_depth = self.depth
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





@always_inline
def _same_static_string(lhs: StaticString, rhs: StaticString) -> Bool:
    return lhs.unsafe_ptr() == rhs.unsafe_ptr() or lhs == rhs


@always_inline
def _hash_comp_time(string: StaticString) -> UInt64:
    return hash[HasherType=default_comp_time_hasher](string)
