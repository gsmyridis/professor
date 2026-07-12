from professor.measure import Sample
from std.reflection import SourceLocation

# ===----------------------------------------------------------------------=== #
# Zone statistics
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct ZoneStat[S: Sample](Copyable, Movable):
    """Aggregated statistics for one zone site.

    `mean` and `variance` are per-close statistics of the inclusive elapsed
    delta (`variance` is in squared sample units). Under recursion, inner
    entries contribute their own deltas to count/min/max/mean/variance, while
    `inclusive` spans only the outermost entry. `loc` is part of site identity.
    """

    var name: StaticString
    var loc: SourceLocation
    var count: Int
    var inclusive: Self.S
    var exclusive: Self.S
    var min: Self.S
    var max: Self.S
    var mean: Self.S
    var variance: Self.S

# ===----------------------------------------------------------------------=== #
# Zone statistics
# ===----------------------------------------------------------------------=== #

struct Report[S: Sample](Writable):
    """The result of a profiling run: per-site statistics."""

    var zones: List[ZoneStat[Self.S]]

    def __init__(out self, var zones: List[ZoneStat[Self.S]]):
        self.zones = zones^

    def write_to(self, mut writer: Some[Writer]):
        for ref z in self.zones:
            writer.write(
                z.name,
                " (",
                z.loc,
                ")  count=",
                z.count,
                "  inclusive=",
                z.inclusive,
                "  exclusive=",
                z.exclusive,
                "  min=",
                z.min,
                "  max=",
                z.max,
                "  mean=",
                z.mean,
                "  variance=",
                z.variance,
                "\n",
            )
