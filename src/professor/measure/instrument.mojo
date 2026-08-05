@fieldwise_init
struct MetricDimension(Equatable, ImplicitlyCopyable):
    """The physical dimension of a reportable metric component."""

    var code: Int

    comptime OPAQUE = Self(0)
    comptime TIME = Self(1)
    comptime COUNT = Self(2)
    comptime MEMORY = Self(3)


struct MetricUnit(Copyable):
    """Report-time description of a metric component's storage unit.

    `scale` converts one stored unit into the dimension's canonical unit:
    nanoseconds for time, individual events for counts, and bytes for memory.
    """

    var dimension: MetricDimension
    var scale: Float64
    var symbol: String

    def __init__(
        out self,
        dimension: MetricDimension,
        scale: Float64,
        var symbol: String,
    ):
        self.dimension = dimension
        self.scale = scale
        self.symbol = symbol^


struct MetricField(Copyable):
    """One named component of a metric reading, ready to be tabulated."""

    var name: String
    """Component name, e.g. `"cycles"`. Empty for single-valued metrics."""

    var value: String
    """The component formatted for display, unit included."""

    var scalar: Optional[Float64]
    """Numeric value used for relative comparisons; `None` if incomparable."""

    var unit: Optional[MetricUnit]
    """Storage unit metadata for derived report values, when available."""

    def __init__(
        out self,
        var name: String,
        var value: String,
        scalar: Optional[Float64] = None,
        var unit: Optional[MetricUnit] = None,
    ):
        self.name = name^
        self.value = value^
        self.scalar = scalar
        self.unit = unit^


trait Metric(Copyable, Defaultable, ImplicitlyDeletable, Writable):
    """An absolute reading of some performance metric.

    Metric readings are subtracted to get deltas and added to aggregate them.
    Division by a count and `min`/`max` (both elementwise for multi-valued
    metrics) support per-zone statistics. The `Defaultable` constructor must
    produce the zero reading.
    TODO: derive the implementation of the trait with reflection.
    """

    def __sub__(self, other: Self) -> Self:
        ...

    def __add__(self, other: Self) -> Self:
        ...

    def __truediv__(self, count: Int) -> Self:
        ...

    def min(self, other: Self) -> Self:
        ...

    def max(self, other: Self) -> Self:
        ...

    def scalar_value(self) -> Optional[Float64]:
        """Returns a scalar suitable for relative report comparisons.

        Metrics with multiple values can keep the default. Their values still
        appear in reports, but percentage columns show `N/A`.
        """
        return None

    def fields(self) -> List[MetricField]:
        """Decomposes this reading into the components a report tabulates.

        Single-valued metrics keep the default: one anonymous field formatted
        with `write_to` and compared with `scalar_value`. Multi-valued metrics
        (hardware counters, say) override this to return one named field per
        component; the report then stacks those components under each zone,
        one row per component.

        The field list must have the same length and the same order for every
        reading of a given metric type, including the default-constructed one.
        """
        return [MetricField("", String(self), self.scalar_value())]


trait Instrument(Defaultable, ImplicitlyDeletable, Movable):
    """Produces `Metric` samples on demand."""

    comptime MetricType: Metric
    """Type of the sampled metric."""

    def measure(mut self) -> Self.MetricType:
        """Samples an associated metric.

        Returns:
            The sampled value.
        """
        ...
