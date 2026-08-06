from professor.measure import DataSize, DataSizeUnit, Bytes
from professor.measure.instrument import _MetricInner
from std.reflection import SourceLocation


struct _Anchor[M: _MetricInner](Copyable, Defaultable):
    var label: StaticString
    """Semantic label."""

    var loc: SourceLocation
    """First source location that claimed this anchor."""

    var hit_count: Int
    """Number of times the target profile zone was exited."""

    var inclusive: Self.M
    """Metric including child profile zones."""

    var exclusive: Self.M
    """Metric excluding child profile zones."""

    var inclusive_min: Self.M
    """Minimum inclusive metric."""

    var tracks_data: Bool
    """Whether this anchor's site is workload annotated."""

    var processed_data: Bytes
    """Bytes processed across all invocations of this anchor."""

    def __init__(out self):
        self.label = ""
        self.loc = SourceLocation(0, 0, "")
        self.hit_count = 0
        self.inclusive = Self.M()
        self.exclusive = Self.M()
        self.inclusive_min = Self.M()
        self.tracks_data = False
        self.processed_data = DataSize()

    def reset_measurements(mut self):
        """Clears statistics while preserving the site's identity."""
        self.hit_count = 0
        self.inclusive = Self.M()
        self.exclusive = Self.M()
        self.inclusive_min = Self.M()
        self.processed_data = DataSize()
