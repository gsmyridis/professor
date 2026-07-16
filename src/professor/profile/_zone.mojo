from std.os import abort
from std.sys.intrinsics import unlikely

from professor.measure import Instrument
from ._state import _CoreProfilerState


@fieldwise_init
@explicit_destroy(".close()")
struct _ProfileZone[I: Instrument, C: Int] where C > 0:
    comptime MetricType = Self.I.MetricType

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
        _CoreProfilerState[Self.I, Self.C], MutUntrackedOrigin
    ]
    """Pointer to the global profiler state."""

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

        # Account for recursive calls
        self.prof_state[].current_open_depth = self.depth
        self.prof_state[].current_open_idx = self.parent_index
        ref parent = self.prof_state[].anchors[self.parent_index]
        parent.exclusive = parent.exclusive - delta
