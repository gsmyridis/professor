from std.time import perf_counter_ns
from std.sys import CompilationTarget
from std.os import abort

from .instrument import Instrument, Metric

from professor.arch import read_cycle_counter

# ===----------------------------------------------------------------------=== #
# Wall-clock measurer
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Nanos(Defaultable, ImplicitlyCopyable, Metric):
    """A wall-clock reading in nanoseconds."""

    var value: Int

    def __init__(out self):
        return self.__init__(0)

    def __sub__(self, other: Self) -> Self:
        return Self(self.value - other.value)

    def __add__(self, other: Self) -> Self:
        return Self(self.value + other.value)

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

    def measure(mut self) -> Self.MetricType:
        return Nanos(Int(perf_counter_ns()))


# ===----------------------------------------------------------------------=== #
# Invariant Timestamp Counter
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Cycles(ImplicitlyCopyable, Metric):
    var value: UInt64

    def __init__(out self):
        return self.__init__(0)

    def __sub__(self, other: Self) -> Self:
        return Self(self.value - other.value)

    def __add__(self, other: Self) -> Self:
        return Self(self.value + other.value)

    def __mul__(self, other: Self) -> Self:
        return Self(self.value * other.value)

    def __truediv__(self, count: Int) -> Self:
        return Self(self.value // UInt64(count))

    def min(self, other: Self) -> Self:
        return self if self.value < other.value else other

    def max(self, other: Self) -> Self:
        return self if self.value > other.value else other

    def scalar_value(self) -> Optional[Float64]:
        return Float64(self.value)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, "cycles")


@fieldwise_init
struct InvariantTSC(Instrument):
    comptime MetricType = Cycles

    var value: UInt64

    def __init__(out self):
        return self.__init__(0)

    def measure(mut self) -> Self.MetricType:
        return Cycles(read_cycle_counter())
