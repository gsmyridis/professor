from .instrument import (
    MetricComponent,
    MType,
    _ScalarMetric,
)

comptime Nanos = Time[TimeUnit.Nanos]
"""Nanoseconds."""

comptime Cycles = Count["cycles"]
"""Clock cycles."""

comptime Ticks = Count["tsc_ticks"]
"""Timestamp counter ticks."""

comptime Bytes = DataSize[DataSizeUnit.Byte]
"""Bytes."""

# ===----------------------------------------------------------------------=== #
# Time
# ===----------------------------------------------------------------------=== #


struct TimeUnit(Equatable, ImplicitlyCopyable, Writable):
    """A time unit and its scale in canonical nanoseconds."""

    var _value: Int
    var scale: UInt64
    var symbol: StaticString

    comptime Nanos = Self(_value=0, _scale=1, _symbol="ns")
    comptime Micros = Self(_value=1, _scale=1_000, _symbol="us")
    comptime Millis = Self(_value=2, _scale=1_000_000, _symbol="ms")
    comptime Seconds = Self(_value=3, _scale=1_000_000_000, _symbol="s")
    comptime Minutes = Self(_value=4, _scale=60_000_000_000, _symbol="min")

    @doc_hidden
    def __init__(
        out self, *, _value: Int, _scale: UInt64, _symbol: StaticString
    ):
        self._value = _value
        self.scale = _scale
        self.symbol = _symbol

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.symbol)


@fieldwise_init
struct Time[unit: TimeUnit = TimeUnit.Nanos](
    Defaultable,
    ImplicitlyCopyable,
    Writable,
    _ScalarMetric,
):
    """An elapsed-time quantity stored in its compile-time unit."""

    var value: UInt64

    def __init__(out self):
        self.value = 0

    def in_unit[target: TimeUnit](self) -> Float64:
        comptime assert Self.unit.scale > 0, "time unit scale must be positive"
        comptime assert (
            target.scale > 0
        ), "target time unit scale must be positive"
        return (
            Float64(self.value)
            * Float64(Self.unit.scale)
            / Float64(target.scale)
        )

    def sub(self, other: Self) -> Self:
        comptime assert Self.unit.scale > 0, "time unit scale must be positive"
        return Self(self.value - other.value)

    def add(self, other: Self) -> Self:
        return Self(self.value + other.value)

    def div(self, count: UInt64) -> Self:
        return Self(self.value // count)

    def min(self, other: Self) -> Self:
        return self if self.value < other.value else other

    def max(self, other: Self) -> Self:
        return self if self.value > other.value else other

    def _component(self, var name: String) -> MetricComponent:
        comptime assert Self.unit.scale > 0, "time unit scale must be positive"
        return MetricComponent(
            name^,
            String(),
            MType.Time,
            self.value,
            Self.unit.scale,
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, Self.unit)


# ===----------------------------------------------------------------------=== #
# Count
# ===----------------------------------------------------------------------=== #


struct CountUnit(Equatable, ImplicitlyCopyable, Writable):
    """An event-count unit and its scale in individual events."""

    var _value: Int
    var scale: UInt64
    var symbol: StaticString
    """The SI prefix, empty for individual events."""

    comptime Single = Self(_value=0, _scale=1, _symbol="")
    comptime Thousand = Self(_value=1, _scale=1_000, _symbol="k")
    comptime Million = Self(_value=2, _scale=1_000_000, _symbol="Mil")
    comptime Billion = Self(_value=3, _scale=1_000_000_000, _symbol="Bil")

    @doc_hidden
    def __init__(
        out self, *, _value: Int, _scale: UInt64, _symbol: StaticString
    ):
        self._value = _value
        self.scale = _scale
        self.symbol = _symbol

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.symbol)


@fieldwise_init
struct Count[
    kind: StaticString,
    unit: CountUnit = CountUnit.Single,
](Defaultable, ImplicitlyCopyable, Writable, _ScalarMetric):
    """A semantic event count stored in its compile-time unit."""

    var value: UInt64

    def __init__(out self):
        self.value = 0

    def in_unit[target: CountUnit](self) -> Float64:
        comptime assert Self.unit.scale > 0, "count unit scale must be positive"
        comptime assert (
            target.scale > 0
        ), "target count unit scale must be positive"
        return (
            Float64(self.value)
            * Float64(Self.unit.scale)
            / Float64(target.scale)
        )

    def sub(self, other: Self) -> Self:
        comptime assert Self.unit.scale > 0, "count unit scale must be positive"
        return Self(self.value - other.value)

    def add(self, other: Self) -> Self:
        return Self(self.value + other.value)

    def div(self, count: UInt64) -> Self:
        return Self(self.value // count)

    def min(self, other: Self) -> Self:
        return self if self.value < other.value else other

    def max(self, other: Self) -> Self:
        return self if self.value > other.value else other

    def _component(self, var name: String) -> MetricComponent:
        comptime assert Self.unit.scale > 0, "count unit scale must be positive"
        if name.byte_length() == 0:
            name = String(Self.kind)
        return MetricComponent(
            name^,
            String(Self.kind),
            MType.Count,
            self.value,
            Self.unit.scale,
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, Self.unit, Self.kind)


# ===----------------------------------------------------------------------=== #
# Data size
# ===----------------------------------------------------------------------=== #


struct DataSizeUnit(Equatable, ImplicitlyCopyable, Writable):
    """An SI data-size unit and its scale in canonical bytes."""

    var _value: Int
    var scale: UInt64
    var symbol: StaticString

    comptime Byte = Self(_value=0, _scale=1, _symbol="B")
    comptime Kilobyte = Self(_value=1, _scale=1_000, _symbol="kB")
    comptime Megabyte = Self(_value=2, _scale=1_000_000, _symbol="MB")
    comptime Gigabyte = Self(_value=3, _scale=1_000_000_000, _symbol="GB")
    comptime Terabyte = Self(_value=4, _scale=1_000_000_000_000, _symbol="TB")

    @doc_hidden
    def __init__(
        out self, *, _value: Int, _scale: UInt64, _symbol: StaticString
    ):
        self._value = _value
        self.scale = _scale
        self.symbol = _symbol

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.symbol)


@fieldwise_init
struct DataSize[unit: DataSizeUnit = DataSizeUnit.Byte](
    Defaultable, ImplicitlyCopyable, Writable, _ScalarMetric
):
    """A data quantity stored in its compile-time unit."""

    var value: UInt64

    def __init__(out self):
        self.value = 0

    def in_unit[target: DataSizeUnit](self) -> Float64:
        comptime assert (
            Self.unit.scale > 0
        ), "data-size unit scale must be positive"
        comptime assert (
            target.scale > 0
        ), "target data-size unit scale must be positive"
        return (
            Float64(self.value)
            * Float64(Self.unit.scale)
            / Float64(target.scale)
        )

    def sub(self, other: Self) -> Self:
        comptime assert (
            Self.unit.scale > 0
        ), "data-size unit scale must be positive"
        return Self(self.value - other.value)

    def add(self, other: Self) -> Self:
        return Self(self.value + other.value)

    def div(self, count: UInt64) -> Self:
        return Self(self.value // count)

    def min(self, other: Self) -> Self:
        return self if self.value < other.value else other

    def max(self, other: Self) -> Self:
        return self if self.value > other.value else other

    def _component(self, var name: String) -> MetricComponent:
        comptime assert (
            Self.unit.scale > 0
        ), "data-size unit scale must be positive"
        return MetricComponent(
            name^,
            String(),
            MType.DataSize,
            self.value,
            Self.unit.scale,
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, Self.unit)
