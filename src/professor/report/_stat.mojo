from professor.measure import Metric
from std.reflection import SourceLocation


@fieldwise_init
struct ZoneStat[S: Metric](Copyable, Movable):
    """Aggregated statistics for one profiling call site."""

    var name: StaticString
    var loc: SourceLocation
    var count: Int
    var inclusive: Self.S
    var exclusive: Self.S
