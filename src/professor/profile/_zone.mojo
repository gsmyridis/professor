from std.os import abort
from std.sys.intrinsics import unlikely

from professor.measure import Instrument
from ._consts import is_profiling_enabled
from ._state import _CoreProfilerState


@explicit_destroy
struct _DisabledProfileZone(Movable):
    @always_inline
    def __init__(out self):
        pass

    @always_inline
    def close(deinit self):
        pass


@fieldwise_init
@explicit_destroy("The profiling zone must be closed with: .close()")
struct _EnabledProfileZone[I: Instrument, C: Int, origin: MutOrigin](
    Movable
) where (C > 0):
    comptime MetricType = Self.I.MetricType
    """Type of the performance metric."""

    var label: StaticString
    """Semantic label."""

    var anchor_index: Int
    """Index of target anchor in the profiler state."""

    var parent_index: Int
    """Index of the anchor that is parent to the target anchor."""

    var depth: Int
    """Depth of the profiling zone."""

    var metric_inclusive_prev: Self.MetricType
    """The target anchor's inclusive metric when the block opened."""

    var metric_open: Self.MetricType
    """Value of the metric when the block was opened."""

    var prof_state: UnsafePointer[
        _CoreProfilerState[Self.I, Self.C], Self.origin
    ]
    """Pointer to the profiler state."""

    def close(deinit self):
        # Sample first so close-side bookkeeping stays out of the interval.
        var sample = self.prof_state[].instrument.measure()
        var delta = sample - self.metric_open

        # Check for LIFO for profiling zones
        # TODO: Add a compile-time flag to gate it
        if unlikely(self.prof_state[].current_open_depth != self.depth + 1):
            abort("Mismatch open and close")

        ref anchor = self.prof_state[].anchors[self.anchor_index]
        anchor.hit_count += 1
        anchor.exclusive = anchor.exclusive + delta
        anchor.inclusive = self.metric_inclusive_prev + delta

        if unlikely(anchor.hit_count == 1):
            anchor.inclusive_min = delta.copy()
        else:
            anchor.inclusive_min = anchor.inclusive_min.min(delta)

        # Account for recursive calls
        self.prof_state[].current_open_depth = self.depth
        self.prof_state[].current_open_idx = self.parent_index
        ref parent = self.prof_state[].anchors[self.parent_index]
        parent.exclusive = parent.exclusive - delta


@explicit_destroy("The profiling zone must be closed with: .close()")
struct _ProfileZone[I: Instrument, C: Int, origin: MutOrigin] where C > 0:
    """A profile-zone handle that is empty when profiling is disabled."""

    comptime _EnabledType = _EnabledProfileZone[Self.I, Self.C, Self.origin]
    comptime _DisabledType = _DisabledProfileZone

    comptime _StorageType: Movable = (
        Self._EnabledType if is_profiling_enabled() else Self._DisabledType
    )

    var _storage: Self._StorageType

    @always_inline
    def __init__(out self):
        comptime assert not is_profiling_enabled()
        self._storage = rebind_var[Self._StorageType](_DisabledProfileZone())

    @always_inline
    def __init__(out self, var enabled: Self._EnabledType):
        comptime assert is_profiling_enabled()
        self._storage = rebind_var[Self._StorageType](enabled^)

    @always_inline
    def __enter__(self):
        """Enters the zone's scope in a `with` statement.

        The measurement interval starts when the zone is created, not here;
        this only enables `with Prof.zone["name"]():` syntax.
        """
        pass

    @always_inline
    def __exit__(deinit self):
        """Closes the zone when its `with` scope exits, including on the
        unwind path of a raising body."""
        self^.close()

    @always_inline
    def close(deinit self):
        comptime if is_profiling_enabled():
            var enabled = rebind_var[Self._EnabledType](self._storage^)
            enabled^.close()
        else:
            var disabled = rebind_var[Self._DisabledType](self._storage^)
            disabled^.close()
