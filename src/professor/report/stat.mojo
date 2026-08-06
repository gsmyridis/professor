from professor.measure import DataSize
from professor.measure.instrument import _MetricInner
from std.reflection import SourceLocation


@fieldwise_init
struct ZoneStatistics[S: _MetricInner](Copyable, Movable):
    """Aggregated statistics for one profiling zone."""

    var name: StaticString
    """Name of the zone."""

    var loc: SourceLocation
    """Source location."""

    var count: Int
    """Hit count."""

    var inclusive: Self.S
    """Inclusive metric, including child zones."""

    var exclusive: Self.S
    """Exclusive metric, excluding child zones."""

    var inclusive_min: Self.S
    """Minimum inclusive metric across invocations."""

    var processed_data: Optional[DataSize[]]
    """Processed bytes when this site records workload size."""
