from professor.measure import Metric
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

    def __init__(out self):
        self.label = ""
        self.loc = SourceLocation(0, 0, "")
        self.hit_count = 0
        self.inclusive = Self.M()
        self.exclusive = Self.M()
