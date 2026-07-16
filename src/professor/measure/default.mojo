from std.time import perf_counter_ns

from .instrument import Instrument, Metric

# ===----------------------------------------------------------------------=== #
# Wall-clock measurer
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Nanos(Defaultable, ImplicitlyCopyable, Metric):
    """A wall-clock reading in nanoseconds.

    Products of `Nanos` (as accumulated for variance) are in squared
    nanoseconds even though they print with the plain unit.
    """

    var value: Int

    def __init__(out self):
        return self.__init__(0)

    def __sub__(self, other: Self) -> Self:
        return Self(self.value - other.value)

    def __add__(self, other: Self) -> Self:
        return Self(self.value + other.value)

    def __mul__(self, other: Self) -> Self:
        return Self(self.value * other.value)

    def __truediv__(self, count: Int) -> Self:
        return Self(self.value // count)

    def min(self, other: Self) -> Self:
        return self if self.value < other.value else other

    def max(self, other: Self) -> Self:
        return self if self.value > other.value else other

    def scalar_value(self) -> Optional[Float64]:
        return Float64(self.value)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, "ns")


struct WallClock(Instrument):
    """An `Instrument` that reads the monotonic wall clock."""

    comptime MetricType = Nanos

    def __init__(out self):
        pass

    def measure(mut self) -> Nanos:
        return Nanos(Int(perf_counter_ns()))
