struct MetricField(Copyable):
    """One named component of a metric reading, ready to be tabulated."""

    var name: String
    """Component name, e.g. `"cycles"`. Empty for single-valued metrics."""

    var value: String
    """The component formatted for display, unit included."""

    var scalar: Optional[Float64]
    """Numeric value used for relative comparisons; `None` if incomparable."""

    def __init__(
        out self,
        var name: String,
        var value: String,
        scalar: Optional[Float64] = None,
    ):
        self.name = name^
        self.value = value^
        self.scalar = scalar


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
    """Produces `Metric` samples on demand (wall clock, hardware counters, ...).
    """

    comptime MetricType: Metric

    def measure(mut self) -> Self.MetricType:
        ...
