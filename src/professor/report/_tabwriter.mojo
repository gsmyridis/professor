from professor.measure import Metric
from std.pathlib import cwd
from std.sys import stdout

from ._stat import ZoneStat


comptime _RED = "\033[31m"
comptime _YELLOW = "\033[33m"
comptime _GREEN = "\033[32m"
comptime _RESET = "\033[0m"


struct _TabWriter[S: Metric](Writable):
    """Dynamically aligned, terminal-aware table for zone statistics."""

    var total: Self.S
    var zones: List[ZoneStat[Self.S]]

    def __init__(
        out self, var total: Self.S, var zones: List[ZoneStat[Self.S]]
    ):
        self.total = total^
        self.zones = zones^

    def write_to(self, mut writer: Some[Writer]):
        comptime ZONE_LABEL = "Zone"
        comptime SITE_LABEL = "Site"
        comptime COUNT_LABEL = "Count"
        comptime INCLUSIVE_LABEL = "Inclusive"
        comptime EXCLUSIVE_LABEL = "Exclusive"
        comptime PER_ITER_LABEL = "Time/iter"
        comptime PERCENT_LABEL = "% Total"

        var root = String()
        try:
            root = String(cwd())
        except:
            pass

        var zone_width = ZONE_LABEL.byte_length()
        var site_width = SITE_LABEL.byte_length()
        var count_width = COUNT_LABEL.byte_length()
        var inclusive_width = INCLUSIVE_LABEL.byte_length()
        var exclusive_width = EXCLUSIVE_LABEL.byte_length()
        var per_iter_width = PER_ITER_LABEL.byte_length()
        var percent_width = PERCENT_LABEL.byte_length()
        var total_scalar = self.total.scalar_value()

        for ref zone in self.zones:
            var name = String(zone.name)
            var site = _site(zone, root)
            var count = String(zone.count)
            var inclusive = String(zone.inclusive)
            var exclusive = String(zone.exclusive)
            var per_iter = String(zone.inclusive / zone.count)
            var percent = _percent(zone.inclusive.scalar_value(), total_scalar)

            zone_width = max(zone_width, name.byte_length())
            site_width = max(site_width, site.byte_length())
            count_width = max(count_width, count.byte_length())
            inclusive_width = max(inclusive_width, inclusive.byte_length())
            exclusive_width = max(exclusive_width, exclusive.byte_length())
            per_iter_width = max(per_iter_width, per_iter.byte_length())
            percent_width = max(percent_width, percent.byte_length())

        writer.write("Program total: ", self.total, "\n\n")

        writer.write(
            ZONE_LABEL,
            _padding(zone_width, ZONE_LABEL),
            "  ",
            SITE_LABEL,
            _padding(site_width, SITE_LABEL),
            "  ",
            _padding(count_width, COUNT_LABEL),
            COUNT_LABEL,
            "  ",
            _padding(inclusive_width, INCLUSIVE_LABEL),
            INCLUSIVE_LABEL,
            "  ",
            _padding(exclusive_width, EXCLUSIVE_LABEL),
            EXCLUSIVE_LABEL,
            "  ",
            _padding(per_iter_width, PER_ITER_LABEL),
            PER_ITER_LABEL,
            "  ",
            _padding(percent_width, PERCENT_LABEL),
            PERCENT_LABEL,
            "\n",
        )
        writer.write(
            "-" * zone_width,
            "  ",
            "-" * site_width,
            "  ",
            "-" * count_width,
            "  ",
            "-" * inclusive_width,
            "  ",
            "-" * exclusive_width,
            "  ",
            "-" * per_iter_width,
            "  ",
            "-" * percent_width,
            "\n",
        )

        if len(self.zones) == 0:
            writer.write("(no zones recorded)\n")
            return

        var use_color = stdout.isatty()
        for ref zone in self.zones:
            var name = String(zone.name)
            var site = _site(zone, root)
            var count = String(zone.count)
            var inclusive = String(zone.inclusive)
            var exclusive = String(zone.exclusive)
            var per_iter = String(zone.inclusive / zone.count)
            var percent_value = _percent_value(
                zone.inclusive.scalar_value(), total_scalar
            )
            var percent = _format_percent(percent_value)

            writer.write(
                name,
                _padding(zone_width, name),
                "  ",
                site,
                _padding(site_width, site),
                "  ",
                _padding(count_width, count),
                count,
                "  ",
            )
            writer.write(_padding(inclusive_width, inclusive), inclusive, "  ")
            writer.write(_padding(exclusive_width, exclusive), exclusive, "  ")
            writer.write(_padding(per_iter_width, per_iter), per_iter, "  ")
            _write_percent(
                writer,
                percent,
                percent_width,
                percent_value,
                use_color,
            )
            writer.write("\n")


def _site[S: Metric](zone: ZoneStat[S], root: String) -> String:
    var file = String(zone.loc.file_name())
    if file.startswith("./"):
        file = String(file[byte=2:])

    if root:
        var prefix = root + "/"
        if file.startswith(prefix):
            file = String(file[byte = prefix.byte_length() :])

    return String(t"{file}:{zone.loc.line()}:{zone.loc.column()}")


def _padding(width: Int, value: StringSlice) -> String:
    return " " * max(0, width - value.byte_length())


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


def _percent(part: Optional[Float64], total: Optional[Float64]) -> String:
    return _format_percent(_percent_value(part, total))


def _write_percent(
    mut writer: Some[Writer],
    value: String,
    width: Int,
    percent: Optional[Float64],
    use_color: Bool,
):
    writer.write(_padding(width, value))
    if not use_color or not percent:
        writer.write(value)
        return

    if percent.value() >= 50.0:
        writer.write(_RED)
    elif percent.value() >= 20.0:
        writer.write(_YELLOW)
    else:
        writer.write(_GREEN)
    writer.write(value, _RESET)
