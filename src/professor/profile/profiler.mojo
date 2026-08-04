from std.ffi import _Global
from std.memory import OwnedPointer
from std.os import abort
from std.reflection import call_location, SourceLocation
from std.sys.intrinsics import unlikely

from professor.measure import Instrument
from professor.report import Report, ZoneStat

from ._consts import _profiling_is_enabled, UNCLAIMED_ANCHOR_LABEL
from ._registry import _SiteKey, _hash_comp_time, _site_hash
from ._state import (
    ROOT_ANCHOR_INDEX,
    _ProfilerState,
    _CoreProfilerState,
    CAPACITY_DEFAULT,
)
from ._zone import _EnabledProfileZone, _ProfileZone


# ===------------------------------------------------------------------------===
# Runtime profiler
# ===------------------------------------------------------------------------===


@fieldwise_init
struct _DisabledProfilerStorage(RegisterPassable):
    pass


struct Profiler[
    I: Instrument,
    *,
    Capacity: Int = CAPACITY_DEFAULT,
](Movable) where (
    Capacity > 0
):
    """An independently owned profiler initialized at runtime."""

    # ===--------------------------------------------------------------------===
    # Comptime aliases
    # ===--------------------------------------------------------------------===

    comptime MetricType = Self.I.MetricType

    comptime _ProfilerStateType = _ProfilerState[Self.I, Self.Capacity]

    comptime _CoreProfilerStateType = _CoreProfilerState[Self.I, Self.Capacity]

    comptime _EnabledStorageType = OwnedPointer[Self._ProfilerStateType]

    comptime _StorageType: RegisterPassable = (
        Self._EnabledStorageType if _profiling_is_enabled() else _DisabledProfilerStorage
    )

    # ===--------------------------------------------------------------------===
    # Fields
    # ===--------------------------------------------------------------------===

    var _storage: Self._StorageType
    """The heap-owned profiler state when profiling is enabled; otherwise,
    zero-sized disabled storage.
    """

    # ===--------------------------------------------------------------------===
    # Configuration methods
    # ===--------------------------------------------------------------------===

    @staticmethod
    def is_enabled() -> Bool:
        """Returns whether profiling is enabled in this build."""
        return _profiling_is_enabled()

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    def __init__(out self):
        comptime if _profiling_is_enabled():
            self._storage = rebind_var[Self._StorageType](
                Self._EnabledStorageType(Self._ProfilerStateType())
            )
        else:
            self._storage = rebind_var[Self._StorageType](
                _DisabledProfilerStorage()
            )

    def __init__(out self, var instrument: Self.I):
        comptime if _profiling_is_enabled():
            self._storage = rebind_var[Self._StorageType](
                Self._EnabledStorageType(Self._ProfilerStateType(instrument^))
            )
        else:
            _ = instrument^
            self._storage = rebind_var[Self._StorageType](
                _DisabledProfilerStorage()
            )

    # ===--------------------------------------------------------------------===
    # Profiler state access methods
    # ===--------------------------------------------------------------------===

    @always_inline
    def _state[
        mut: Bool, origin: Origin[mut=mut], //
    ](ref[origin] self) -> UnsafePointer[Self._ProfilerStateType, origin]:
        return (
            rebind[Self._EnabledStorageType](self._storage)
            .unsafe_ptr()
            .unsafe_origin_cast[origin]()
        )

    @always_inline
    def _core_state[
        mut: Bool, origin: Origin[mut=mut], //
    ](ref[origin] self) -> UnsafePointer[Self._CoreProfilerStateType, origin]:
        return UnsafePointer(to=self._state()[].core).unsafe_origin_cast[
            origin
        ]()

    # ===--------------------------------------------------------------------===
    # Profiling session methods
    # ===--------------------------------------------------------------------===

    def start(mut self) raises:
        """Starts this profiler's measurement interval."""
        comptime if not _profiling_is_enabled():
            return

        var st = self._core_state()
        if st[].has_started:
            raise Error("start() called more than once")
        if st[].current_open_depth != 0:
            raise Error("start() called while a zone is open")

        # Measure after the checks.
        st[].start_metric = st[].instrument.measure()
        st[].has_started = True

    def end(mut self) raises:
        """Ends this profiler's measurement interval."""
        comptime if not _profiling_is_enabled():
            return

        var st = self._core_state()

        # Measure as early as possible.
        var end_metric = st[].instrument.measure()

        if not st[].has_started:
            raise Error("end() called before start()")
        if st[].has_ended:
            raise Error("end() called more than once")
        if st[].current_open_depth != 0:
            raise Error(
                String(
                    t"end() called with {st[].current_open_depth} zone(s) still"
                    t" open"
                )
            )

        st[].total_metric = end_metric - st[].start_metric
        st[].has_ended = True

    def reset(mut self) raises:
        """Clears measurements while preserving the instrument and sites."""
        comptime if not _profiling_is_enabled():
            return

        var st = self._core_state()
        if st[].current_open_depth != 0:
            raise Error(
                String(
                    t"reset() called with {st[].current_open_depth} zone(s)"
                    t" still open"
                )
            )
        if st[].has_started and not st[].has_ended:
            raise Error("reset() called before end()")

        st[].start_metric = Self.I.MetricType()
        st[].total_metric = Self.I.MetricType()
        st[].has_started = False
        st[].has_ended = False
        st[].current_open_idx = ROOT_ANCHOR_INDEX

        for ref anchor in st[].anchors:
            anchor.reset_measurements()

    # ===--------------------------------------------------------------------===
    # Profile zone creation
    # ===--------------------------------------------------------------------===

    @always_inline
    def zone[
        origin: MutOrigin, //, name: StaticString, index: Int
    ](ref[origin] self) -> _ProfileZone[Self.I, Self.Capacity, origin] where (
        index >= ROOT_ANCHOR_INDEX and index < Self.Capacity
    ):
        """Opens a zone targeting an explicitly selected anchor."""
        comptime if _profiling_is_enabled():
            var loc = call_location()
            return self._zone_at[name, index](loc)
        else:
            return _ProfileZone[Self.I, Self.Capacity, origin]()

    @always_inline
    def zone[
        origin: MutOrigin, //, name: StaticString
    ](ref[origin] self) -> _ProfileZone[Self.I, Self.Capacity, origin]:
        """Opens a zone resolved from its label and source location."""
        comptime if _profiling_is_enabled():
            var loc = call_location()
            return self._zone_at[name](loc)
        else:
            return _ProfileZone[Self.I, Self.Capacity, origin]()

    @always_inline
    def _zone_at[
        origin: MutOrigin, //, name: StaticString, index: Int
    ](
        ref[origin] self,
        loc: SourceLocation,
    ) -> _ProfileZone[
        Self.I, Self.Capacity, origin
    ] where (index >= ROOT_ANCHOR_INDEX and index < Self.Capacity):
        var st = self._core_state()
        return _open_zone[name](st, index + 1, loc)

    @always_inline
    def _zone_at[
        origin: MutOrigin, //, name: StaticString
    ](ref[origin] self, loc: SourceLocation) -> _ProfileZone[
        Self.I, Self.Capacity, origin
    ]:
        comptime name_hash = _hash_comp_time(name)
        var st = self._state()
        var h = _site_hash(name_hash, loc)
        var key = _SiteKey(h, name, loc.file_name(), loc.line(), loc.column())
        var idx = st[].registry.get_index(key^)
        var core = UnsafePointer(to=st[].core).unsafe_origin_cast[origin]()
        return _open_zone[name](core, idx, loc)

    # ===--------------------------------------------------------------------===
    # Produce report
    # ===--------------------------------------------------------------------===

    def report(self) raises -> Report[Self.I.MetricType]:
        """Derives per-site statistics from the completed session."""
        comptime if not _profiling_is_enabled():
            return Report[Self.I.MetricType]()

        var st = self._core_state()
        var open_count = st[].current_open_depth
        if open_count != 0:
            raise Error(
                String(t"report() called with {open_count} zone(s) still open")
            )
        if not st[].has_ended:
            raise Error("report() called before end()")
        var stats = List[ZoneStat[Self.I.MetricType]](
            capacity=len(st[].anchors)
        )
        for ref a in st[].anchors:
            if a.hit_count == 0:
                continue
            stats.append(
                ZoneStat[Self.I.MetricType](
                    a.label,
                    a.loc,
                    a.hit_count,
                    a.inclusive.copy(),
                    a.exclusive.copy(),
                    a.inclusive_min.copy(),
                )
            )
        return Report[Self.I.MetricType](st[].total_metric.copy(), stats^)


# ===------------------------------------------------------------------------===
# Global profiler
# ===------------------------------------------------------------------------===


struct GlobalProfiler[
    I: Instrument,
    *,
    Capacity: Int = CAPACITY_DEFAULT,
    Tag: StaticString = "default",
] where (
    Capacity > 0
):
    """Static facade over one globally stored runtime profiler."""

    # ===--------------------------------------------------------------------===
    # Comptime aliases
    # ===--------------------------------------------------------------------===

    comptime ProfilerType = Profiler[Self.I, Capacity=Self.Capacity]

    comptime MetricType = Self.I.MetricType

    comptime _global_profiler = _Global[Self.Tag, Self._init]

    # ===--------------------------------------------------------------------===
    # Configuration methods
    # ===--------------------------------------------------------------------===

    @staticmethod
    def is_enabled() -> Bool:
        """Returns whether profiling is enabled in this build."""
        return Self.ProfilerType.is_enabled()

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    @staticmethod
    def _init() -> Self.ProfilerType:
        return Self.ProfilerType()

    # ===--------------------------------------------------------------------===
    # Profiler state access methods
    # ===--------------------------------------------------------------------===

    @staticmethod
    @always_inline
    def _profiler() -> UnsafePointer[Self.ProfilerType, MutUntrackedOrigin]:
        try:
            return Self._global_profiler.get_or_create_ptr()
        except:
            abort("failed to get or create global profiler")

    # ===--------------------------------------------------------------------===
    # Profiling session methods
    # ===--------------------------------------------------------------------===

    @staticmethod
    def start() raises:
        comptime if _profiling_is_enabled():
            Self._profiler()[].start()

    @staticmethod
    def end() raises:
        comptime if _profiling_is_enabled():
            Self._profiler()[].end()

    @staticmethod
    def reset() raises:
        comptime if _profiling_is_enabled():
            Self._profiler()[].reset()

    @staticmethod
    def report() raises -> Report[Self.MetricType]:
        comptime if _profiling_is_enabled():
            return Self._profiler()[].report()
        else:
            return Report[Self.MetricType]()

    @always_inline
    @staticmethod
    def zone[
        name: StaticString, index: Int
    ]() -> _ProfileZone[Self.I, Self.Capacity, MutUntrackedOrigin] where (
        index >= ROOT_ANCHOR_INDEX and index < Self.Capacity
    ):
        comptime if _profiling_is_enabled():
            var loc = call_location()
            return Self._profiler()[]._zone_at[name, index](loc)
        else:
            return _ProfileZone[Self.I, Self.Capacity, MutUntrackedOrigin]()

    @always_inline
    @staticmethod
    def zone[
        name: StaticString
    ]() -> _ProfileZone[Self.I, Self.Capacity, MutUntrackedOrigin]:
        comptime if _profiling_is_enabled():
            var loc = call_location()
            return Self._profiler()[]._zone_at[name](loc)
        else:
            return _ProfileZone[Self.I, Self.Capacity, MutUntrackedOrigin]()


@always_inline
def _open_zone[
    I: Instrument,
    C: Int,
    origin: MutOrigin,
    //,
    label: StaticString,
](
    st: UnsafePointer[_CoreProfilerState[I, C], origin],
    idx: Int,
    loc: SourceLocation,
) -> _ProfileZone[I, C, origin] where (C > 0):
    comptime assert label != UNCLAIMED_ANCHOR_LABEL, String(
        t"The semantic label of a profiling zone cannot be empty, i.e."
        t" ('{UNCLAIMED_ANCHOR_LABEL}')."
    )

    if unlikely(not st[].has_started or st[].has_ended):
        abort("profile zones must be opened between start() and end()")

    var parent = st[].current_open_idx
    var depth = st[].current_open_depth

    st[].current_open_idx = idx
    st[].current_open_depth = depth + 1

    ref anchor = st[].anchors[idx]
    var prev_inclusive = anchor.inclusive.copy()

    # When opening a zone, if the zone is not claimed we set its label.
    # Since we claim a zone only once, and every other time we use an
    # existing one, we mark it as unlikely.
    # TODO: Add more efficient comparison of static strings
    if unlikely(anchor.label == UNCLAIMED_ANCHOR_LABEL):
        anchor.label = label
        anchor.loc = loc

    # We place the error condition behind an unlikely hint because it is,
    # and also if it is, we do not care about the performance.
    # TODO: Place it behind a comptime flag like CHECK
    if unlikely(anchor.label != label):
        abort(
            String(
                t"profile anchor {idx} is already claimed by '{anchor.label}'; "
                t"cannot claim it as '{label}'"
            )
        )

    # Sample as late as possible so open-side bookkeeping stays out of the
    # measured interval.
    var sample = st[].instrument.measure()

    return _ProfileZone[I, C, origin](
        _EnabledProfileZone[I, C, origin](
            label,
            idx,
            parent,
            depth,
            prev_inclusive^,
            sample^,
            st,
        )
    )
