trait Sample(Copyable, Defaultable, Writable, ImplicitlyDeletable):
    """An absolute reading of some performance metric.

    Sample readings are subtracted to get deltas and added to aggregate them.
    Multiplication, division by a count, and `min`/`max` (all elementwise for
    multi-valued samples) support online statistics: the profiler accumulates
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


trait Measurer(Movable, ImplicitlyDeletable):
    """Produces `Sample`s on demand (wall clock, hardware counters, ...)."""

    comptime S: Sample

    def measure(mut self) -> Self.S:
        ...
