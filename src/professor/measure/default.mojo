from std.time import perf_counter_ns

from ._measure import Sample, Measurer

# ===----------------------------------------------------------------------=== #
# Wall-clock measurer
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Nanos(Defaultable, ImplicitlyCopyable, Sample):
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

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, "ns")


struct WallClock(Measurer):
    """A `Measurer` that reads the monotonic wall clock."""

    comptime S = Nanos

    def __init__(out self):
        pass

    def measure(mut self) -> Nanos:
        return Nanos(Int(perf_counter_ns()))
