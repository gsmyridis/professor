"""Lays a `Report` out as one `Table` per metric component.

Everything metric-specific lives here; `_table` knows only about strings,
widths and colors. A metric that decomposes into several components (cycles
and retired instructions, say) gets one table each, so every table can be read
-- and eventually sorted -- along its own axis.
"""

from professor.measure import (
    Memory,
    Metric,
    MetricDimension,
    MetricField,
    Throughput,
)
from std.os.path import dirname
from std.pathlib import cwd, Path
from std.reflection import SourceLocation

from .stat import ZoneStatistics
from .table import Align, Cell, Color, Column, Table, TableStyle


comptime _ZONE_LABEL = "Zone"
comptime _SITE_LABEL = "Site"
comptime _COUNT_LABEL = "Count"
comptime _INCLUSIVE_LABEL = "Inclusive"
comptime _EXCLUSIVE_LABEL = "Exclusive"
comptime _INCLUSIVE_MIN_LABEL = "Min. Inclusive"
comptime _INCLUSIVE_PER_ITER_LABEL = "Inclusive/Iter"
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
"""Any of these marks the project root, whose prefix is stripped from sites."""


def zone_tables[
    M: Metric
](total: M, stats: List[ZoneStatistics[M]]) raises -> List[Table]:
    """Builds one per-zone table for each scalar component of the metric.

    A single-valued metric yields exactly one table, titled with the program
    total.

    Args:
        total: Metric for the whole duration of the profiling.
        stats: Aggregate statistics for each zone.

    Returns:
        A list of tables displaying the zone statistics for each scalar
        component of the performance metric.
    """
    # The total's fields define the report's shape: one table per component,
    # in the order the metric declares them. `Metric.fields()` requires every
    # reading to agree; `_component_table` checks it as it reads them.
    var total_fields = total.fields()
    var count = len(total_fields)

    var root = _project_root()

    var tables = List[Table](capacity=count)
    for index in range(count):
        tables.append(_component_table(total_fields, stats, index, root))
    return tables^


def _component_table[
    S: Metric
](
    total_fields: List[MetricField],
    stats: List[ZoneStatistics[S]],
    index: Int,
    root: String,
) raises -> Table:
    var show_throughput = _is_time_field(total_fields[index]) and _has_memory(
        stats
    )
    var columns = [
        Column(_ZONE_LABEL),
        Column(_SITE_LABEL),
        Column(_COUNT_LABEL, align=Align.RIGHT),
        Column(_INCLUSIVE_LABEL, align=Align.RIGHT),
        Column(_EXCLUSIVE_LABEL, align=Align.RIGHT),
        Column(_INCLUSIVE_MIN_LABEL, align=Align.RIGHT),
        Column(_INCLUSIVE_PER_ITER_LABEL, align=Align.RIGHT),
    ]
    if show_throughput:
        columns.append(Column(_THROUGHPUT_LABEL, align=Align.RIGHT))
    columns.append(Column(_INCLUSIVE_PERCENT_LABEL, align=Align.RIGHT))
    columns.append(Column(_EXCLUSIVE_PERCENT_LABEL, align=Align.RIGHT))

    var table = Table(
        _title(total_fields, index),
        columns^,
        TableStyle(),
    )

    for ref stat in stats:
        var inclusive = stat.inclusive.fields()
        var exclusive = stat.exclusive.fields()
        var inclusive_min = stat.inclusive_min.fields()
        var inclusive_per_iter = (stat.inclusive / stat.count).fields()

        _check_shape(inclusive, total_fields)
        _check_shape(exclusive, total_fields)
        _check_shape(inclusive_min, total_fields)
        _check_shape(inclusive_per_iter, total_fields)

        var incl_percent = _percent_value(
            inclusive[index].scalar, total_fields[index].scalar
        )
        var excl_percent = _percent_value(
            exclusive[index].scalar, total_fields[index].scalar
        )
        var cells = [
            Cell(String(stat.name)),
            Cell(_format_site(stat.loc, root)),
            Cell(String(stat.count)),
            Cell(inclusive[index].value.copy()),
            Cell(exclusive[index].value.copy()),
            Cell(inclusive_min[index].value.copy()),
            Cell(inclusive_per_iter[index].value.copy()),
        ]
        if show_throughput:
            cells.append(
                Cell(_format_throughput(stat.memory, inclusive[index]))
            )
        cells.append(
            Cell(
                _format_percent(incl_percent),
                color=_percent_color(incl_percent),
            )
        )
        cells.append(
            Cell(
                _format_percent(excl_percent),
                color=_percent_color(excl_percent),
            )
        )
        table.add_row(cells^)

    if len(stats) == 0:
        # A row carries one cell per column; the empty ones are not rendered,
        # so this reads as a single line under the header.
        var cells = List[Cell](capacity=table.num_columns())
        cells.append(Cell("(no zones recorded)"))
        for _ in range(table.num_columns() - 1):
            cells.append(Cell(String()))
        table.add_row(cells^)

    return table^


def _title(total_fields: List[MetricField], index: Int) -> String:
    """Names the component and states its program-wide total."""
    ref field = total_fields[index]
    if field.name:
        return String(t"{field.name} — total {field.value}")
    return String(t"Program total: {field.value}")


# ===----------------------------------------------------------------------=== #
# Helpers
# ===----------------------------------------------------------------------=== #


def _project_root() raises -> String:
    """Returns the directory holding a manifest, searching upwards from `cwd`.

    Reported sites are written relative to it, so the report reads the same
    however deep in the tree the program was started from. A program run
    outside any project has no root to speak of: this returns an empty string
    and sites keep their full path, which is unwieldy but not wrong.
    """
    var directory = String(cwd())
    while True:
        for manifest in _MANIFESTS:
            if (Path(directory) / manifest).is_file():
                return directory^
        var parent = dirname(directory)
        # `dirname` is its own fixed point at the filesystem root.
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


def _check_shape(
    fields: List[MetricField], total_fields: List[MetricField]
) raises:
    """Raises unless `fields` decomposes the way the program total does.

    Names, not just counts: a reading that reorders its fields would keep the
    length and quietly hand every table another component's numbers.
    """
    comptime SHAPE_ERROR = (
        "Metric.fields() must return the same fields, with the same names and"
        " in the same order, for every reading."
    )
    if len(fields) != len(total_fields):
        raise Error(SHAPE_ERROR)
    for i in range(len(fields)):
        if fields[i].name != total_fields[i].name:
            raise Error(SHAPE_ERROR)
        if fields[i].unit and not total_fields[i].unit:
            raise Error(SHAPE_ERROR)
        if total_fields[i].unit and not fields[i].unit:
            raise Error(SHAPE_ERROR)
        if fields[i].unit:
            ref unit = fields[i].unit.value()
            ref total_unit = total_fields[i].unit.value()
            if (
                unit.dimension != total_unit.dimension
                or unit.scale != total_unit.scale
                or unit.symbol != total_unit.symbol
            ):
                raise Error(SHAPE_ERROR)


def _has_memory[S: Metric](stats: List[ZoneStatistics[S]]) -> Bool:
    for ref stat in stats:
        if stat.memory:
            return True
    return False


def _is_time_field(field: MetricField) -> Bool:
    if not field.unit:
        return False
    return field.unit.value().dimension == MetricDimension.TIME


def _format_throughput(
    memory: Optional[Memory[]], field: MetricField
) -> String:
    if not memory or not field.scalar or not field.unit:
        return "N/A"
    ref unit = field.unit.value()
    if unit.dimension != MetricDimension.TIME:
        return "N/A"
    var elapsed_nanos = field.scalar.value() * unit.scale
    if elapsed_nanos <= 0.0:
        return "N/A"

    return String(Throughput(memory.value(), elapsed_nanos))


def _percent_value(
    part: Optional[Float64], total: Optional[Float64]
) -> Optional[Float64]:
    if not part or not total or total.value() <= 0.0:
        return None
    return part.value() * 100.0 / total.value()


def _format_percent(percent: Optional[Float64]) -> String:
    if not percent:
        return "N/A"
    var rounded = Float64(Int(percent.value() * 10.0 + 0.5)) / 10.0
    return String(t"{rounded}%")


def _percent_color(percent: Optional[Float64]) -> Color:
    if not percent:
        return Color.DEFAULT
    if percent.value() >= _HOT_PERCENT:
        return Color.RED
    if percent.value() >= _WARM_PERCENT:
        return Color.YELLOW
    return Color.GREEN
