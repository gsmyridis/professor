from professor.measure import Instrument
from ._anchor import _Anchor
from ._registry import _Registry

comptime ROOT_ANCHOR_INDEX = 0
comptime CAPACITY_DEFAULT = 1024

# ===------------------------------------------------------------------------===
# Core profiler state
# ===------------------------------------------------------------------------===


struct _CoreProfilerState[I: Instrument, Capacity: Int](
    Defaultable, Movable
) where (Capacity > 0):
    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    comptime MetricType = Self.I.MetricType
    """Profiling metric type."""

    comptime _AnchorArrayType = InlineArray[
        _Anchor[Self.MetricType], 2 * Self.Capacity
    ]

    # ===--------------------------------------------------------------------===
    # Fields
    # ===--------------------------------------------------------------------===

    var instrument: Self.I
    """Instrument that gives samples."""

    var anchors: Self._AnchorArrayType
    """Array of profile anchors."""

    var current_open_idx: Int
    """Anchor index targeted by current open profile zone."""

    var current_open_depth: Int
    """Depth of the current open zone."""
    # TODO: Change the name, it should probably be next open

    # ===--------------------------------------------------------------------===
    # Life-cycle methods
    # ===--------------------------------------------------------------------===

    def __init__(out self):
        self.anchors = Self._AnchorArrayType(fill=_Anchor[Self.MetricType]())
        self.instrument = Self.I()
        self.current_open_idx = ROOT_ANCHOR_INDEX
        self.current_open_depth = 0


# ===------------------------------------------------------------------------===
# Profiler state
# ===------------------------------------------------------------------------===


struct _ProfilerState[I: Instrument, Capacity: Int](
    Defaultable, Movable
) where (Capacity > 0):
    var core: _CoreProfilerState[Self.I, Self.Capacity]
    var registry: _Registry[Self.Capacity]

    def __init__(out self):
        self.core = _CoreProfilerState[Self.I, Self.Capacity]()
        self.registry = _Registry[Self.Capacity]()
