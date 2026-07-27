"""Lays a `Report` out as one `Table` per metric component.

Everything metric-specific lives here; `_table` knows only about strings,
widths and colors. A metric that decomposes into several components (cycles
and retired instructions, say) gets one table each, so every table can be read
-- and eventually sorted -- along its own axis.
"""

from professor.measure import Metric, MetricField
from std.pathlib import cwd

from ._stat import ZoneStat
from ._table import Align, Cell, Color, Column, Table


comptime _ZONE_LABEL = "Zone"
comptime _SITE_LABEL = "Site"
comptime _COUNT_LABEL = "Count"
comptime _INCLUSIVE_LABEL = "Inclusive"
comptime _EXCLUSIVE_LABEL = "Exclusive"
comptime _PER_ITER_LABEL = "Per iter"
comptime _PERCENT_LABEL = "% Total"

comptime _HOT_PERCENT = 50.0
comptime _WARM_PERCENT = 20.0


def zone_tables[S: Metric](total: S, zones: List[ZoneStat[S]]) -> List[Table]:
    """Builds one per-zone table for each component of the metric.

    A single-valued metric yields exactly one table, titled with the program
    total.
    """
    var total_fields = total.fields()
    for ref field in total_fields:
        print(field.name, field.value, field.scalar)
    print("--")

    # `Metric.fields()` is documented to return a fixed-length list, but a
    # metric that breaks it must not lose components: give every index that
    # appears anywhere in the report a table of its own.
    var count = len(total_fields)
    for ref zone in zones:
        count = max(count, len(zone.inclusive.fields()))

    var root = String()
    try:
        root = String(cwd())
    except:
        pass

    var tables = List[Table](capacity=count)
    for index in range(count):
        tables.append(_component_table(total_fields, zones, index, root))
    return tables^


def _component_table[
    S: Metric
](
    total_fields: List[MetricField],
    zones: List[ZoneStat[S]],
    index: Int,
    root: String,
) -> Table:
    var table = Table(
        [
            Column(_ZONE_LABEL),
            Column(_SITE_LABEL),
            Column(_COUNT_LABEL, align=Align.RIGHT),
            Column(_INCLUSIVE_LABEL, align=Align.RIGHT),
            Column(_EXCLUSIVE_LABEL, align=Align.RIGHT),
            Column(_PER_ITER_LABEL, align=Align.RIGHT),
            Column(_PERCENT_LABEL, align=Align.RIGHT),
        ]
    )
    table.title = _title(total_fields, index)

    for ref zone in zones:
        var inclusive = zone.inclusive.fields()
        var exclusive = zone.exclusive.fields()
        var per_iter = (zone.inclusive / zone.count).fields()

        var percent = _percent_value(
            _field_scalar(inclusive, index), _field_scalar(total_fields, index)
        )
        var cells = [
            Cell(String(zone.name)),
            Cell(_site(zone, root)),
            Cell(String(zone.count)),
            Cell(_field_value(inclusive, index)),
            Cell(_field_value(exclusive, index)),
            Cell(_field_value(per_iter, index)),
            Cell(_format_percent(percent), color=_percent_color(percent)),
        ]
        table.add_row(cells^)

    if len(zones) == 0:
        var cells = [Cell("(no zones recorded)")]
        table.add_row(cells^)

    return table^


def _title(total_fields: List[MetricField], index: Int) -> String:
    """Names the component and states its program-wide total."""
    if index >= len(total_fields):
        return String()

    ref field = total_fields[index]
    if field.name:
        return String(t"{field.name} — total {field.value}")
    return String(t"Program total: {field.value}")


# ===----------------------------------------------------------------------=== #
# Helpers
# ===----------------------------------------------------------------------=== #


def _site[S: Metric](zone: ZoneStat[S], root: String) -> String:
    var file = String(zone.loc.file_name())
    if file.startswith("./"):
        file = String(file[byte=2:])

    if root:
        var prefix = root + "/"
        if file.startswith(prefix):
            file = String(file[byte = prefix.byte_length() :])

    return String(t"{file}:{zone.loc.line()}:{zone.loc.column()}")


def _field_value(fields: List[MetricField], index: Int) -> String:
    """Returns field `index`, or a placeholder if the metric is inconsistent."""
    if index >= len(fields):
        return String("N/A")
    return fields[index].value.copy()


def _field_scalar(fields: List[MetricField], index: Int) -> Optional[Float64]:
    if index >= len(fields):
        return None
    return fields[index].scalar


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
