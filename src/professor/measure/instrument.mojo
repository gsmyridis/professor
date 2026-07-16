trait Metric(Copyable, Defaultable, ImplicitlyDeletable, Writable):
    """An absolute reading of some performance metric.

    Metric readings are subtracted to get deltas and added to aggregate them.
    Multiplication, division by a count, and `min`/`max` (all elementwise for
    multi-valued metrics) support online statistics: the profiler accumulates
    a sum and a sum of squares per zone, from which the report derives mean
    and variance. The `Defaultable` constructor must produce the zero reading.
    TODO: derive the implementation of the trait with reflection.
    """

    def __sub__(self, other: Self) -> Self:
        ...

    def __add__(self, other: Self) -> Self:
        ...

    def __mul__(self, other: Self) -> Self:
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


trait Instrument(Defaultable, ImplicitlyDeletable, Movable):
    """Produces `Metric` samples on demand (wall clock, hardware counters, ...).
    """

    comptime MetricType: Metric

    def measure(mut self) -> Self.MetricType:
        ...
