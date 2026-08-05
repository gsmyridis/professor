from professor.measure import Memory, Metric
from std.reflection import SourceLocation


@fieldwise_init
struct ZoneStatistics[S: Metric](Copyable, Movable):
    """Aggregated statistics for one profiling zone."""

    var name: StaticString
    """Name of the zone."""

    var loc: SourceLocation
    """Source location."""

    var count: Int
    """Hit count."""

    var inclusive: Self.S
    """Inclusive time."""

    var exclusive: Self.S
    """Exclusive time."""

    var inclusive_min: Self.S
    """Minimum inclusive time."""

    var memory: Optional[Memory[]]
    """Processed bytes when this site records workload size."""
