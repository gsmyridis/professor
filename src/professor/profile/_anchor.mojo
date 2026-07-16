from professor.measure import Metric


struct _Anchor[M: Metric](Copyable, Defaultable):
    var label: StaticString
    """Semantic label."""

    var hit_count: Int
    """Number of times the target profile zone was exited."""

    var inclusive: Self.M
    """Metric metrics including child profile zones."""

    var exclusive: Self.M
    """Metric metrics excluding child profile zones."""

    def __init__(out self):
        self.label = ""
        self.hit_count = 0
        self.inclusive = Self.M()
        self.exclusive = Self.M()
