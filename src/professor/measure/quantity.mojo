from .instrument import (
    Metric,
    MetricDimension,
    MetricField,
    MetricUnit,
)


# ===----------------------------------------------------------------------=== #
# Units
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct TimeUnit(Equatable, ImplicitlyCopyable, Writable):
    """A time unit and its scale in canonical nanoseconds."""

    var code: Int
    var scale: Int

    comptime NANOS = Self(0, 1)
    comptime MICROS = Self(1, 1_000)
    comptime MILLIS = Self(2, 1_000_000)
    comptime SECONDS = Self(3, 1_000_000_000)
    comptime MINUTES = Self(4, 60_000_000_000)

    def write_to(self, mut writer: Some[Writer]):
        if self == Self.NANOS:
            writer.write("ns")
        elif self == Self.MICROS:
            writer.write("us")
        elif self == Self.MILLIS:
            writer.write("ms")
        elif self == Self.SECONDS:
            writer.write("s")
        elif self == Self.MINUTES:
            writer.write("min")


@fieldwise_init
struct CountUnit(Equatable, ImplicitlyCopyable, Writable):
    """An event-count unit and its scale in individual events."""

    var code: Int
    var scale: Int

    comptime SINGLE = Self(0, 1)
    comptime THOUSAND = Self(1, 1_000)
    comptime MILLION = Self(2, 1_000_000)
    comptime BILLION = Self(3, 1_000_000_000)

    def write_to(self, mut writer: Some[Writer]):
        if self == Self.THOUSAND:
            writer.write("k")
        elif self == Self.MILLION:
            writer.write("M")
        elif self == Self.BILLION:
            writer.write("G")


@fieldwise_init
struct MemoryUnit(Equatable, ImplicitlyCopyable, Writable):
    """A decimal memory unit and its scale in bytes."""

    var code: Int
    var scale: Int

    comptime BYTE = Self(0, 1)
    comptime KILOBYTE = Self(1, 1_000)
    comptime MEGABYTE = Self(2, 1_000_000)
    comptime GIGABYTE = Self(3, 1_000_000_000)
    comptime TERABYTE = Self(4, 1_000_000_000_000)

    def write_to(self, mut writer: Some[Writer]):
        if self == Self.BYTE:
            writer.write("B")
        elif self == Self.KILOBYTE:
            writer.write("kB")
        elif self == Self.MEGABYTE:
            writer.write("MB")
        elif self == Self.GIGABYTE:
            writer.write("GB")
        elif self == Self.TERABYTE:
            writer.write("TB")


# ===----------------------------------------------------------------------=== #
# Scalar quantities
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Time[unit: TimeUnit = TimeUnit.NANOS](
    Defaultable, ImplicitlyCopyable, Metric
):
    """A time reading stored in its compile-time unit."""

    var value: Int

    def __init__(out self):
        self.value = 0

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

    def in_unit[target: TimeUnit](self) -> Float64:
        return (
            Float64(self.value)
            * Float64(Self.unit.scale)
            / Float64(target.scale)
        )

    def scalar_value(self) -> Optional[Float64]:
        return Float64(self.value)

    def fields(self) -> List[MetricField]:
        return [self.field()]

    def field[name: StaticString = ""](self) -> MetricField:
        return MetricField(
            String(name),
            String(self),
            self.scalar_value(),
            MetricUnit(
                MetricDimension.TIME,
                Float64(Self.unit.scale),
                String(Self.unit),
            ),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, Self.unit)


@fieldwise_init
struct Count[
    name: StaticString,
    unit: CountUnit = CountUnit.SINGLE,
](Defaultable, ImplicitlyCopyable, Metric):
    """A named event count stored in its compile-time unit."""

    var value: Int

    def __init__(out self):
        self.value = 0

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

    def in_unit[target: CountUnit](self) -> Float64:
        return (
            Float64(self.value)
            * Float64(Self.unit.scale)
            / Float64(target.scale)
        )

    def scalar_value(self) -> Optional[Float64]:
        return Float64(self.value)

    def fields(self) -> List[MetricField]:
        return [self.field()]

    def field(self) -> MetricField:
        return MetricField(
            String(Self.name),
            String(self),
            self.scalar_value(),
            MetricUnit(
                MetricDimension.COUNT,
                Float64(Self.unit.scale),
                String(Self.unit),
            ),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, Self.unit, Self.name)


@fieldwise_init
struct Memory[unit: MemoryUnit = MemoryUnit.BYTE](
    Defaultable, ImplicitlyCopyable, Metric
):
    """A memory quantity stored in its compile-time unit."""

    var value: Int

    def __init__(out self):
        self.value = 0

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

    def in_unit[target: MemoryUnit](self) -> Float64:
        return (
            Float64(self.value)
            * Float64(Self.unit.scale)
            / Float64(target.scale)
        )

    def scalar_value(self) -> Optional[Float64]:
        return Float64(self.value)

    def fields(self) -> List[MetricField]:
        return [self.field()]

    def field[name: StaticString = ""](self) -> MetricField:
        return MetricField(
            String(name),
            String(self),
            self.scalar_value(),
            MetricUnit(
                MetricDimension.MEMORY,
                Float64(Self.unit.scale),
                String(Self.unit),
            ),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, Self.unit)


@fieldwise_init
struct Throughput(Copyable, Writable):
    """A report-time byte rate with time normalized to nanoseconds."""

    var memory: Memory[]
    var elapsed_nanos: Float64

    def in_units(
        self, memory_unit: MemoryUnit, time_unit: TimeUnit
    ) -> Optional[Float64]:
        if self.elapsed_nanos <= 0.0:
            return None
        var memory = Float64(self.memory.value) / Float64(memory_unit.scale)
        var time = self.elapsed_nanos / Float64(time_unit.scale)
        return memory / time

    def write_to(self, mut writer: Some[Writer]):
        var rate = self.in_units(MemoryUnit.GIGABYTE, TimeUnit.SECONDS)
        if not rate:
            writer.write("N/A")
            return
        var rounded = Float64(Int(rate.value() * 1_000.0 + 0.5)) / 1_000.0
        writer.write(rounded, " GB/s")


comptime Nanos = Time[TimeUnit.NANOS]
comptime Cycles = Count["cycles"]
