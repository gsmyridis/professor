from std.ffi import _Global
from std.os import abort
from std.sys.intrinsics import unlikely
from std.reflection import call_location

from professor.measure import Instrument
from ._anchor import _Anchor
from ._state import (
    ROOT_ANCHOR_INDEX,
    _ProfilerState,
    _CoreProfilerState,
    CAPACITY_DEFAULT,
)
from ._zone import _ProfileZone
from ._consts import UNCLAIMED_ANCHOR_LABEL
from ._registry import _SiteKey, _hash_comp_time, _site_hash
from .report import Report, ZoneStat


# ===------------------------------------------------------------------------===
# Profiler
# ===------------------------------------------------------------------------===


struct Profiler[
    I: Instrument,
    *,
    Capacity: Int = CAPACITY_DEFAULT,
    Tag: StaticString = "default",
] where (
    Capacity > 0
):
    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    comptime _ProfilerStateType = _ProfilerState[Self.I, Self.Capacity]

    comptime _CoreProfilerStateType = _CoreProfilerState[Self.I, Self.Capacity]

    comptime _global_state = _Global[Self.Tag, Self._init]
    """Global profiler state."""

    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    @staticmethod
    def _init() -> Self._ProfilerStateType:
        """Constructs the profiler state."""
        return Self._ProfilerStateType()

    @staticmethod
    def _state() -> UnsafePointer[Self._ProfilerStateType, MutUntrackedOrigin]:
        """Returns an unsafe pointer to the profiler state."""
        try:
            return Self._global_state.get_or_create_ptr()
        except e:
            abort("failed to get or create global state pointer")

    @staticmethod
    @always_inline
    def _core_state() -> (
        UnsafePointer[Self._CoreProfilerStateType, MutUntrackedOrigin]
    ):
        """Returns an unsafe pointer to the core profiler state."""
        var state = Self._state()
        return UnsafePointer(to=state[].core)

    # ===--------------------------------------------------------------------===
    # Profile zone creation
    # ===--------------------------------------------------------------------===

    @always_inline
    @staticmethod
    def zone[
        name: StaticString, index: Int
    ]() -> _ProfileZone[Self.I, Self.Capacity] where (
        index >= ROOT_ANCHOR_INDEX and index < Self.Capacity
    ):
        """Opens the zone `name` targeting the profile anchor with `index`.

        The index is specified to bypass the runtime resolution of the target
        anchor by semantic name and call-site resolution.

        Parameters:
            name: Semantic name of the profile zone.
            index: Index of target profile anchor.

        Returns:
            Linear profile zone handle.
        """
        # var loc = call_location()  # TODO: Use it also
        var st = Self._core_state()
        return _open_zone[name](st, index + 1)

    @always_inline
    @staticmethod
    def zone[name: StaticString]() -> _ProfileZone[Self.I, Self.Capacity]:
        """Opens the profile zone `name`.

        The target profile anchor is resolved during runtime based on the
        name of the zone and the call-location.

        Parameters:
            name: Semantic name of the profile zone.

        Returns:
            Linear profile zone handle.
        """
        # Must be a `var`: bound with `comptime`, `call_location()` evaluates
        # in parameter context where the location is unknown (0:0), and every
        # same-named site collapses into one anchor.
        var loc = call_location()
        comptime name_hash = _hash_comp_time(name)
        var st = Self._state()
        var h = _site_hash(name_hash, loc)
        var key = _SiteKey(h, name, loc.file_name(), loc.line(), loc.column())
        var idx = st[].registry.get_index(key^)
        return _open_zone[name](UnsafePointer(to=st[].core), idx)

    # ===--------------------------------------------------------------------===
    # Produce report
    # ===--------------------------------------------------------------------===

    @staticmethod
    def report() raises -> Report[Self.I.MetricType]:
        """Derives per-site statistics from the anchor table.

        Raises if any zone is still open: exclusive times are transiently
        inconsistent (children already subtracted, parent not yet added), so
        a report taken now would be garbage.
        """
        var st = Self._core_state()
        var open_count = st[].current_open_depth
        if open_count != 0:
            raise Error(
                String(t"report() called with {open_count} zone(s) still open")
            )
        var stats = List[ZoneStat[Self.I.MetricType]](
            capacity=len(st[].anchors)
        )
        for ref a in st[].anchors:
            if a.hit_count == 0:
                continue
            stats.append(
                ZoneStat[Self.I.MetricType](
                    a.label,
                    # a.loc,
                    a.hit_count,
                    a.inclusive.copy(),
                    a.exclusive.copy(),
                )
            )
        return Report[Self.I.MetricType](stats^)


@always_inline
def _open_zone[
    I: Instrument, C: Int, //, label: StaticString
](
    st: UnsafePointer[_CoreProfilerState[I, C], MutUntrackedOrigin],
    idx: Int,
) -> _ProfileZone[I, C] where (C > 0):
    comptime assert label != UNCLAIMED_ANCHOR_LABEL, String(
        t"The semantic label of a profiling zone cannot be empty, i.e."
        t" ('{UNCLAIMED_ANCHOR_LABEL}')."
    )

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

    # We place the error condition behind an unlikely hint because it is,
    # and also if it is, we do not care about the performance.
    # TODO: Add a message
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

    return _ProfileZone[I](
        label, idx, parent, depth, prev_inclusive^, sample^, st
    )
