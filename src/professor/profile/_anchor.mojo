from professor.measure import Memory, Metric, MemoryUnit
from std.reflection import SourceLocation


struct _Anchor[M: Metric](Copyable, Defaultable):
    var label: StaticString
    """Semantic label."""

    var loc: SourceLocation
    """First source location that claimed this anchor."""

    var hit_count: Int
    """Number of times the target profile zone was exited."""

    var inclusive: Self.M
    """Metric metrics including child profile zones."""

    var exclusive: Self.M
    """Metric metrics excluding child profile zones."""

    var inclusive_min: Self.M
    """Minimum inclusive metric."""

    var tracks_memory: Bool
    """Whether this anchor's zones record processed bytes."""

    var memory: Memory[MemoryUnit.BYTE]
    """Bytes processed across the same intervals as `inclusive`."""

    def __init__(out self):
        self.label = ""
        self.loc = SourceLocation(0, 0, "")
        self.hit_count = 0
        self.inclusive = Self.M()
        self.exclusive = Self.M()
        self.inclusive_min = Self.M()
        self.tracks_memory = False
        self.memory = Memory()

    def reset_measurements(mut self):
        """Clears statistics while preserving the site's identity."""
        self.hit_count = 0
        self.inclusive = Self.M()
        self.exclusive = Self.M()
        self.inclusive_min = Self.M()
        self.memory = Memory()
