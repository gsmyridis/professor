from std.ffi import _Global
from std.memory import OwnedPointer
from std.os import abort
from std.reflection import call_location, SourceLocation
from std.sys.intrinsics import unlikely

from professor.measure import Bytes, Instrument
from professor.report import Report, ReportFormat, ZoneStatistics

from ._consts import is_profiling_enabled, UNCLAIMED_ANCHOR_LABEL
from ._registry import _SiteKey, _hash_comp_time, _site_hash
from ._state import (
    ROOT_ANCHOR_INDEX,
    _ProfilerState,
    _CoreProfilerState,
    CAPACITY_DEFAULT,
)
from ._zone import (
    _EnabledProfileZone,
    _ProfileZone,
)


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
        Self._EnabledStorageType if is_profiling_enabled() else _DisabledProfilerStorage
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
        return is_profiling_enabled()

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    def __init__(out self):
        comptime if is_profiling_enabled():
            self._storage = rebind_var[Self._StorageType](
                Self._EnabledStorageType(Self._ProfilerStateType())
            )
        else:
            self._storage = rebind_var[Self._StorageType](
                _DisabledProfilerStorage()
            )

    def __init__(out self, var instrument: Self.I):
        comptime if is_profiling_enabled():
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
    ](ref[origin] self) -> Pointer[Self._ProfilerStateType, origin]:
        return (
            rebind[Self._EnabledStorageType](self._storage)
            .unsafe_ptr()
            .unsafe_origin_cast[origin]()
        )

    @always_inline
    def _core_state[
        mut: Bool, origin: Origin[mut=mut], //
    ](ref[origin] self) -> Pointer[Self._CoreProfilerStateType, origin]:
        return Pointer(to=self._state()[].core).unsafe_origin_cast[origin]()

    # ===--------------------------------------------------------------------===
    # Profiling session methods
    # ===--------------------------------------------------------------------===

    def start(mut self) raises:
        """Starts this profiler's measurement interval.

        Raises:
            If the profiler is running, or has an open zone.
        """
        comptime if not is_profiling_enabled():
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
        """Ends this profiler's measurement interval.

        Raises:
            If the profiler is not running, or has an open zone.
        """
        comptime if not is_profiling_enabled():
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

        st[].total_metric = end_metric.sub(st[].start_metric)
        st[].has_ended = True

    def reset(mut self) raises:
        """Clears measurements while preserving the instrument and sites."""
        comptime if not is_profiling_enabled():
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

        st[].start_metric = Self.MetricType()
        st[].total_metric = Self.MetricType()
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
        comptime if is_profiling_enabled():
            var loc = call_location()
            return self._zone_at[name, index](loc)
        else:
            return _ProfileZone[Self.I, Self.Capacity, origin]()

    @always_inline
    def zone[
        origin: MutOrigin, //, name: StaticString, index: Int
    ](
        ref[origin] self,
        *,
        bytes: UInt64,
    ) -> _ProfileZone[
        Self.I, Self.Capacity, origin, True
    ] where (index >= ROOT_ANCHOR_INDEX and index < Self.Capacity):
        """Opens a pinned zone that records processed bytes."""
        comptime if is_profiling_enabled():
            var loc = call_location()
            return self._zone_at[name, index](loc, bytes)
        else:
            return _ProfileZone[Self.I, Self.Capacity, origin, True]()

    @always_inline
    def zone[
        origin: MutOrigin, //, name: StaticString
    ](ref[origin] self) -> _ProfileZone[Self.I, Self.Capacity, origin]:
        """Opens a zone resolved from its label and source location."""
        comptime if is_profiling_enabled():
            var loc = call_location()
            return self._zone_at[name](loc)
        else:
            return _ProfileZone[Self.I, Self.Capacity, origin]()

    @always_inline
    def zone[
        origin: MutOrigin, //, name: StaticString
    ](
        ref[origin] self,
        *,
        bytes: UInt64,
    ) -> _ProfileZone[
        Self.I, Self.Capacity, origin, True
    ]:
        """Opens a site-resolved zone that records processed bytes."""
        comptime if is_profiling_enabled():
            var loc = call_location()
            return self._zone_at[name](loc, bytes)
        else:
            return _ProfileZone[Self.I, Self.Capacity, origin, True]()

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
        return _open_zone[False, name](st, index + 1, loc, UInt64(0))

    @always_inline
    def _zone_at[
        origin: MutOrigin, //, name: StaticString, index: Int
    ](
        ref[origin] self,
        loc: SourceLocation,
        bytes: UInt64,
    ) -> _ProfileZone[
        Self.I, Self.Capacity, origin, True
    ] where (index >= ROOT_ANCHOR_INDEX and index < Self.Capacity):
        var st = self._core_state()
        return _open_zone[True, name](st, index + 1, loc, bytes)

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
        var core = Pointer(to=st[].core).unsafe_origin_cast[origin]()
        return _open_zone[False, name](core, idx, loc, 0)

    @always_inline
    def _zone_at[
        origin: MutOrigin, //, name: StaticString
    ](
        ref[origin] self,
        loc: SourceLocation,
        bytes: UInt64,
    ) -> _ProfileZone[
        Self.I, Self.Capacity, origin, True
    ]:
        comptime name_hash = _hash_comp_time(name)
        var st = self._state()
        var h = _site_hash(name_hash, loc)
        var key = _SiteKey(h, name, loc.file_name(), loc.line(), loc.column())
        var idx = st[].registry.get_index(key^)
        var core = Pointer(to=st[].core).unsafe_origin_cast[origin]()
        return _open_zone[True, name](core, idx, loc, bytes)

    # ===--------------------------------------------------------------------===
    # Produce report
    # ===--------------------------------------------------------------------===

    def report(
        self, var format: ReportFormat = ReportFormat()
    ) raises -> Report[Self.MetricType]:
        """Derives per-site statistics from the completed session.

        Args:
            format: Formatting options for the produced report.

        Returns:
            The report.

        Raises:
            If the profiling has not been completed, or there is an open zone.
        """
        comptime if not is_profiling_enabled():
            return Report[Self.MetricType](format^)

        var st = self._core_state()
        var open_count = st[].current_open_depth
        if open_count != 0:
            raise Error(
                String(t"report() called with {open_count} zone(s) still open")
            )
        if not st[].has_ended:
            raise Error("report() called before end()")

        var stats = List[ZoneStatistics[Self.MetricType]](
            capacity=len(st[].anchors)
        )
        for ref a in st[].anchors:
            if a.hit_count == 0:
                continue
            var processed_data: Optional[Bytes] = None
            if a.tracks_data:
                processed_data = a.processed_data
            stats.append(
                ZoneStatistics[Self.MetricType](
                    a.label,
                    a.loc,
                    a.hit_count,
                    a.inclusive.copy(),
                    a.exclusive.copy(),
                    a.inclusive_min.copy(),
                    processed_data,
                )
            )
        return Report[Self.MetricType](
            st[].total_metric.copy(), stats^, format^
        )


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
    def _profiler() -> Pointer[Self.ProfilerType, MutUntrackedOrigin]:
        try:
            return Self._global_profiler.get_or_create_ptr()
        except:
            abort("failed to get or create global profiler")

    # ===--------------------------------------------------------------------===
    # Profiling session methods
    # ===--------------------------------------------------------------------===

    @staticmethod
    def start() raises:
        comptime if is_profiling_enabled():
            Self._profiler()[].start()

    @staticmethod
    def end() raises:
        comptime if is_profiling_enabled():
            Self._profiler()[].end()

    @staticmethod
    def reset() raises:
        comptime if is_profiling_enabled():
            Self._profiler()[].reset()

    @staticmethod
    def report(
        var format: ReportFormat = ReportFormat(),
    ) raises -> Report[Self.MetricType]:
        comptime if is_profiling_enabled():
            return Self._profiler()[].report(format^)
        else:
            return Report[Self.MetricType](format^)

    @always_inline
    @staticmethod
    def zone[
        name: StaticString, index: Int
    ]() -> _ProfileZone[Self.I, Self.Capacity, MutUntrackedOrigin] where (
        index >= ROOT_ANCHOR_INDEX and index < Self.Capacity
    ):
        comptime if is_profiling_enabled():
            var loc = call_location()
            return Self._profiler()[]._zone_at[name, index](loc)
        else:
            return _ProfileZone[Self.I, Self.Capacity, MutUntrackedOrigin]()

    @always_inline
    @staticmethod
    def zone[
        name: StaticString, index: Int
    ](*, bytes: UInt64) -> _ProfileZone[
        Self.I, Self.Capacity, MutUntrackedOrigin, True
    ] where (index >= ROOT_ANCHOR_INDEX and index < Self.Capacity):
        """Opens a pinned global zone that records processed bytes."""
        comptime if is_profiling_enabled():
            var loc = call_location()
            return Self._profiler()[]._zone_at[name, index](loc, bytes)
        else:
            return _ProfileZone[
                Self.I, Self.Capacity, MutUntrackedOrigin, True
            ]()

    @always_inline
    @staticmethod
    def zone[
        name: StaticString
    ]() -> _ProfileZone[Self.I, Self.Capacity, MutUntrackedOrigin]:
        comptime if is_profiling_enabled():
            var loc = call_location()
            return Self._profiler()[]._zone_at[name](loc)
        else:
            return _ProfileZone[Self.I, Self.Capacity, MutUntrackedOrigin]()

    @always_inline
    @staticmethod
    def zone[
        name: StaticString
    ](*, bytes: UInt64) -> _ProfileZone[
        Self.I, Self.Capacity, MutUntrackedOrigin, True
    ]:
        """Opens a site-resolved global zone that records processed bytes."""
        comptime if is_profiling_enabled():
            var loc = call_location()
            return Self._profiler()[]._zone_at[name](loc, bytes)
        else:
            return _ProfileZone[
                Self.I, Self.Capacity, MutUntrackedOrigin, True
            ]()


@always_inline
def _open_zone[
    I: Instrument,
    C: Int,
    origin: MutOrigin,
    //,
    tracks_data: Bool,
    label: StaticString,
](
    st: Pointer[_CoreProfilerState[I, C], origin],
    idx: Int,
    loc: SourceLocation,
    bytes: UInt64,
) -> _ProfileZone[I, C, origin, tracks_data] where (C > 0):
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
        anchor.tracks_data = tracks_data

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

    if unlikely(anchor.tracks_data != tracks_data):
        abort(
            String(
                t"profile anchor {idx} cannot mix ordinary and byte-tracking"
                t" zones"
            )
        )

    # Sample as late as possible so open-side bookkeeping stays out of the
    # measured interval.
    var sample = st[].instrument.measure()

    return _ProfileZone[I, C, origin, tracks_data](
        _EnabledProfileZone[I, C, origin, tracks_data](
            label,
            idx,
            parent,
            depth,
            prev_inclusive^,
            sample^,
            bytes,
            st,
        )
    )
