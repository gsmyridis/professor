from professor.measure import Memory, Metric
from std.reflection import SourceLocation


@fieldwise_init
struct ZoneStat[S: Metric](Copyable, Movable):
    """Aggregated statistics for one profiling call site."""

    var name: StaticString
    var loc: SourceLocation
    var count: Int
    var inclusive: Self.S
    var exclusive: Self.S
    var inclusive_min: Self.S
    var memory: Optional[Memory[]]
    """Processed bytes when this site records workload size."""
