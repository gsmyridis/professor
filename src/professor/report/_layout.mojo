"""Materializes typed profiler results as one table per scalar component."""

from std.math import round
from std.os.path import dirname
from std.pathlib import cwd, Path
from std.reflection import SourceLocation

from professor.measure import (
    CountUnit,
    TimeUnit,
    DataSizeUnit,
)
from professor.measure.instrument import (
    _MetricInner,
    MType,
    MetricComponent,
)

from .format import ReportFormat
from .stat import ZoneStatistics
from .table import Align, Cell, Color, Column, Table, TableStyle

comptime _THOUSAND_SEP = ","
comptime _DECIMAL_SEP = "."
comptime _MAX_DECIMALS = 9

comptime _ZONE_LABEL = "Zone"
comptime _SITE_LABEL = "Site"
comptime _COUNT_LABEL = "Count"
comptime _INCLUSIVE_LABEL = "Inclusive"
comptime _EXCLUSIVE_LABEL = "Exclusive"
comptime _INCLUSIVE_MIN_LABEL = "Min. Inclusive"
comptime _INCLUSIVE_PER_ITER_LABEL = "Inclusive/Iter"
comptime _PROCESSED_DATA_LABEL = "Processed Data"
comptime _THROUGHPUT_LABEL = "Throughput"
comptime _INCLUSIVE_PERCENT_LABEL = "Inclusive (%)"
comptime _EXCLUSIVE_PERCENT_LABEL = "Exclusive (%)"

comptime _HOT_PERCENT = 50.0
comptime _WARM_PERCENT = 20.0

comptime _MANIFESTS: InlineArray[StaticString, 3] = [
    "pixi.toml",
    "uv.toml",
    "pyproject.toml",
]


@fieldwise_init
struct _DisplayUnit(Copyable):
    """The scale and header symbol one report column displays its values in."""

    var scale: UInt64
    var symbol: String

    def __init__(out self, unit: TimeUnit):
        self = Self(unit.scale, String(unit.symbol))

    def __init__(out self, unit: DataSizeUnit):
        self = Self(unit.scale, String(unit.symbol))

    def __init__(out self, unit: CountUnit):
        """Carries only the SI prefix, which is empty for individual events.

        The event kind belongs to the whole table, so it is named once in the
        title rather than repeated in every column header.
        """
        self = Self(unit.scale, String(unit.symbol))


def zone_tables[
    M: _MetricInner
](
    total: M,
    stats: List[ZoneStatistics[M]],
    format: ReportFormat,
) raises -> List[Table]:
    var total_components = total.components()
    var root = _project_root()
    var tables = List[Table](capacity=len(total_components))
    for index in range(len(total_components)):
        tables.append(
            _component_table(total_components, stats, index, root, format)
        )
    return tables^


def _component_table[
    S: _MetricInner
](
    total_components: List[MetricComponent],
    stats: List[ZoneStatistics[S]],
    index: Int,
    root: String,
    format: ReportFormat,
) raises -> Table:
    ref total = total_components[index]
    var tracks_data = _tracks_data_any(stats)
    var show_throughput = total.kind == MType.Time and tracks_data

    var inclusive_unit = _select_component_unit(
        total, _column_max_inclusive(stats, index)
    )
    var exclusive_unit = _select_component_unit(
        total, _column_max_exclusive(stats, index)
    )
    var minimum_unit = _select_component_unit(
        total, _column_max_inclusive_min(stats, index)
    )
    var average_unit = _select_component_unit(
        total, _column_max_inclusive_iter(stats, index)
    )
    var data_unit = _select_data_unit(_column_max_processed_data(stats))
    var throughput_unit = _select_rate_unit(
        _column_max_throughput(stats, index) if show_throughput else 0.0
    )

    var columns = [
        Column(_ZONE_LABEL),
        Column(_SITE_LABEL),
        Column(_COUNT_LABEL, align=Align.Right),
        Column(
            _column_header(_INCLUSIVE_LABEL, inclusive_unit.symbol),
            align=Align.Right,
        ),
        Column(
            _column_header(_EXCLUSIVE_LABEL, exclusive_unit.symbol),
            align=Align.Right,
        ),
        Column(
            _column_header(_INCLUSIVE_MIN_LABEL, minimum_unit.symbol),
            align=Align.Right,
        ),
        Column(
            _column_header(_INCLUSIVE_PER_ITER_LABEL, average_unit.symbol),
            align=Align.Right,
        ),
    ]
    if tracks_data:
        columns.append(
            Column(
                _column_header(_PROCESSED_DATA_LABEL, data_unit.symbol),
                align=Align.Right,
            )
        )
    if show_throughput:
        columns.append(
            Column(
                _column_header(_THROUGHPUT_LABEL, throughput_unit.symbol),
                align=Align.Right,
            )
        )
    columns.append(Column(_INCLUSIVE_PERCENT_LABEL, align=Align.Right))
    columns.append(Column(_EXCLUSIVE_PERCENT_LABEL, align=Align.Right))

    var table = Table(
        _title(total, format),
        columns^,
        TableStyle(),
    )

    for ref stat in stats:
        var inclusive = stat.inclusive.components()[index].copy()
        var exclusive = stat.exclusive.components()[index].copy()
        var inclusive_min = stat.inclusive_min.components()[index].copy()
        var inclusive_value = inclusive.canonical_value()
        var exclusive_value = exclusive.canonical_value()
        var average_value = inclusive_value / Float64(stat.count)
        var total_value = total.canonical_value()

        var incl_percent = _percent_value(inclusive_value, total_value)
        var excl_percent = _percent_value(exclusive_value, total_value)
        var cells = [
            Cell(String(stat.name)),
            Cell(_format_site(stat.loc, root)),
            Cell(_group_integer(UInt64(stat.count))),
            Cell(_format_component(inclusive, inclusive_unit, format)),
            Cell(_format_component(exclusive, exclusive_unit, format)),
            Cell(_format_component(inclusive_min, minimum_unit, format)),
            Cell(
                _format_number(
                    average_value / Float64(average_unit.scale), format
                )
            ),
        ]

        if tracks_data:
            cells.append(Cell(_format_processed_data(stat, data_unit, format)))
        if show_throughput:
            cells.append(
                Cell(
                    _format_throughput(
                        stat, inclusive_value, throughput_unit, format
                    )
                )
            )
        cells.append(
            Cell(
                _format_percent(incl_percent, format),
                color=_percent_color(incl_percent),
            )
        )
        cells.append(
            Cell(
                _format_percent(excl_percent, format),
                color=_percent_color(excl_percent),
            )
        )
        table.add_row(cells^)

    if len(stats) == 0:
        var cells = List[Cell](capacity=table.num_columns())
        cells.append(Cell("(no zones recorded)"))
        for _ in range(table.num_columns() - 1):
            cells.append(Cell(String()))
        table.add_row(cells^)

    return table^


def _title(component: MetricComponent, format: ReportFormat) -> String:
    """Names the whole table, and with it the event kind its columns count.

    Every column of one table measures the same thing, so the kind is stated
    here once; column headers carry only the SI prefix they scale by.
    """
    var unit = _select_component_unit(component, component.canonical_value())
    var quantity = _format_component(component, unit, format)
    if unit.symbol:
        quantity += " " + unit.symbol
    if component.count_kind:
        quantity += " " + component.count_kind
    if component.name:
        return component.name + " - total " + quantity
    return "Program total: " + quantity


# ===----------------------------------------------------------------------=== #
# Unit selection
# ===----------------------------------------------------------------------=== #


def _select_component_unit(
    component: MetricComponent, maximum: Float64
) -> _DisplayUnit:
    if component.kind == MType.Time:
        return _select_time_unit(maximum)
    if component.kind == MType.DataSize:
        return _select_data_unit(maximum)
    return _select_count_unit(maximum)


def _select_count_unit(maximum: Float64) -> _DisplayUnit:
    if maximum >= Float64(CountUnit.Billion.scale):
        return _DisplayUnit(CountUnit.Billion)
    if maximum >= Float64(CountUnit.Million.scale):
        return _DisplayUnit(CountUnit.Million)
    if maximum >= Float64(CountUnit.Thousand.scale):
        return _DisplayUnit(CountUnit.Thousand)
    return _DisplayUnit(CountUnit.Single)


def _select_time_unit(maximum: Float64) -> _DisplayUnit:
    if maximum >= Float64(TimeUnit.Minutes.scale):
        return _DisplayUnit(TimeUnit.Minutes)
    if maximum >= Float64(TimeUnit.Seconds.scale):
        return _DisplayUnit(TimeUnit.Seconds)
    if maximum >= Float64(TimeUnit.Millis.scale):
        return _DisplayUnit(TimeUnit.Millis)
    if maximum >= Float64(TimeUnit.Micros.scale):
        return _DisplayUnit(TimeUnit.Micros)
    return _DisplayUnit(TimeUnit.Nanos)


def _select_data_unit(maximum: Float64) -> _DisplayUnit:
    if maximum >= Float64(DataSizeUnit.Terabyte.scale):
        return _DisplayUnit(DataSizeUnit.Terabyte)
    if maximum >= Float64(DataSizeUnit.Gigabyte.scale):
        return _DisplayUnit(DataSizeUnit.Gigabyte)
    if maximum >= Float64(DataSizeUnit.Megabyte.scale):
        return _DisplayUnit(DataSizeUnit.Megabyte)
    if maximum >= Float64(DataSizeUnit.Kilobyte.scale):
        return _DisplayUnit(DataSizeUnit.Kilobyte)
    return _DisplayUnit(DataSizeUnit.Byte)


def _select_rate_unit(maximum: Float64) -> _DisplayUnit:
    var unit = _select_data_unit(maximum)
    unit.symbol += "/s"
    return unit^


def _column_header(label: String, unit: String) -> String:
    if not unit:
        return label
    return label + " (" + unit + ")"


# ===----------------------------------------------------------------------=== #
# Column values
# ===----------------------------------------------------------------------=== #


def _column_max_inclusive[
    S: _MetricInner
](stats: List[ZoneStatistics[S]], index: Int) -> Float64:
    var maximum = 0.0
    for ref stat in stats:
        var value = stat.inclusive.components()[index].canonical_value()
        maximum = max(maximum, value)
    return maximum


def _column_max_exclusive[
    S: _MetricInner
](stats: List[ZoneStatistics[S]], index: Int) -> Float64:
    var maximum = 0.0
    for ref stat in stats:
        var value = stat.exclusive.components()[index].canonical_value()
        maximum = max(maximum, value)
    return maximum


def _column_max_inclusive_min[
    S: _MetricInner
](stats: List[ZoneStatistics[S]], index: Int) -> Float64:
    var maximum = 0.0
    for ref stat in stats:
        var value = stat.inclusive_min.components()[index].canonical_value()
        maximum = max(maximum, value)
    return maximum


def _column_max_inclusive_iter[
    S: _MetricInner
](stats: List[ZoneStatistics[S]], index: Int) -> Float64:
    var maximum = 0.0
    for ref stat in stats:
        var value = stat.inclusive.components()[
            index
        ].canonical_value() / Float64(stat.count)
        maximum = max(maximum, value)
    return maximum


def _column_max_processed_data[
    S: _MetricInner
](stats: List[ZoneStatistics[S]]) -> Float64:
    var maximum = 0.0
    for ref stat in stats:
        if stat.processed_data:
            maximum = max(maximum, Float64(stat.processed_data.value().value))
    return maximum


def _column_max_throughput[
    S: _MetricInner
](stats: List[ZoneStatistics[S]], index: Int) -> Float64:
    var maximum = 0.0
    for ref stat in stats:
        if not stat.processed_data:
            continue
        var elapsed = stat.inclusive.components()[index].canonical_value()
        if elapsed <= 0.0:
            continue
        var rate = (
            Float64(stat.processed_data.value().value)
            * Float64(TimeUnit.Seconds.scale)
            / elapsed
        )
        maximum = max(maximum, rate)
    return maximum


def _tracks_data_any[S: _MetricInner](stats: List[ZoneStatistics[S]]) -> Bool:
    """Checks if any zone tracks processed-data statistics."""
    for ref stat in stats:
        if stat.processed_data:
            return True
    return False


def _format_processed_data[
    S: _MetricInner
](stat: ZoneStatistics[S], unit: _DisplayUnit, format: ReportFormat) -> String:
    if not stat.processed_data:
        return "N/A"
    return _format_scaled_integer(
        stat.processed_data.value().value, UInt64(1), unit.scale, format
    )


def _format_throughput[
    S: _MetricInner
](
    stat: ZoneStatistics[S],
    elapsed_nanos: Float64,
    unit: _DisplayUnit,
    format: ReportFormat,
) -> String:
    if not stat.processed_data or elapsed_nanos <= 0.0:
        return "N/A"
    var bytes_per_second = (
        Float64(stat.processed_data.value().value)
        * Float64(TimeUnit.Seconds.scale)
        / elapsed_nanos
    )
    return _format_number(bytes_per_second / Float64(unit.scale), format)


# ===----------------------------------------------------------------------=== #
# Numeric formatting
# ===----------------------------------------------------------------------=== #


def _group_integer(value: UInt64) -> String:
    if value == 0:
        return "0"
    var remaining = value
    var result = String()
    var digits = 0
    while remaining > 0:
        if digits > 0 and digits % 3 == 0:
            result = _THOUSAND_SEP + result
        result = String(remaining % 10) + result
        remaining //= 10
        digits += 1
    return result^


def _format_number(value: Float64, format: ReportFormat) -> String:
    """Writes `value` with at most `format.maximum_decimals()` decimals.

    Trailing fractional zeros are dropped, so a value below the last retained
    digit renders as `0`. The requested decimals are clamped to
    `[0, _MAX_DECIMALS]` rather than rejected.
    """
    var decimals = min(max(format.maximum_decimals(), 0), _MAX_DECIMALS)
    var factor = UInt64(10) ** decimals
    var scaled_float = round(value * Float64(factor))
    var scaled = (
        UInt64(scaled_float) if scaled_float
        < Float64(UInt64.MAX) else UInt64.MAX
    )

    var fraction = String(scaled % factor)
    while fraction.byte_length() < decimals:
        fraction = "0" + fraction

    var result = _group_integer(scaled // factor)
    var digits = fraction.rstrip("0")
    if digits:
        result += _DECIMAL_SEP + String(digits)
    return result^


def _format_component(
    component: MetricComponent,
    unit: _DisplayUnit,
    format: ReportFormat,
) -> String:
    return _format_scaled_integer(
        component.value, component.storage_scale, unit.scale, format
    )


def _format_scaled_integer(
    value: UInt64,
    storage_scale: UInt64,
    display_scale: UInt64,
    format: ReportFormat,
) -> String:
    if storage_scale >= display_scale:
        var multiplier = storage_scale // display_scale
        if value <= UInt64.MAX // multiplier:
            return _group_integer(value * multiplier)
    else:
        var divisor = display_scale // storage_scale
        if value % divisor == 0:
            return _group_integer(value // divisor)

    return _format_number(
        Float64(value) * Float64(storage_scale) / Float64(display_scale),
        format,
    )


def _percent_value(part: Float64, total: Float64) -> Optional[Float64]:
    if total <= 0.0:
        return None
    return part * 100.0 / total


def _format_percent(percent: Optional[Float64], format: ReportFormat) -> String:
    if not percent:
        return "N/A"
    var decimals = min(format.maximum_decimals(), 1)
    var percent_format = ReportFormat(max_decimals=decimals)
    return _format_number(percent.value(), percent_format) + "%"


def _percent_color(percent: Optional[Float64]) -> Color:
    if not percent:
        return Color.Default
    if percent.value() >= _HOT_PERCENT:
        return Color.Red
    if percent.value() >= _WARM_PERCENT:
        return Color.Yellow
    return Color.Green


# ===----------------------------------------------------------------------=== #
# Sites
# ===----------------------------------------------------------------------=== #


def _project_root() raises -> String:
    var directory = String(cwd())
    while True:
        for manifest in _MANIFESTS:
            if (Path(directory) / manifest).is_file():
                return directory^
        var parent = dirname(directory)
        if parent == directory:
            return String()
        directory = parent^


def _format_site(loc: SourceLocation, root: String) -> String:
    var file = String(loc.file_name())
    if file.startswith("./"):
        file = String(file[byte=2:])

    if root:
        var prefix = root + "/"
        if file.startswith(prefix):
            file = String(file[byte = prefix.byte_length() :])

    return String(t"{file}:{loc.line()}:{loc.column()}")
