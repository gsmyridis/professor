from std.testing import assert_equal, assert_true, TestSuite

from professor import Instrument, Metric, MetricField, Nanos, Profiler
from professor.report import Align, ColorMode


# A two-component metric: each `measure()` advances both counters by a fixed
# step, so inclusive/exclusive spans are exact.
@fieldwise_init
struct Counters(Defaultable, ImplicitlyCopyable, Metric):
    var cycles: Int
    var instructions: Int

    def __init__(out self):
        self = Self(0, 0)

    def __sub__(self, o: Self) -> Self:
        return Self(self.cycles - o.cycles, self.instructions - o.instructions)

    def __add__(self, o: Self) -> Self:
        return Self(self.cycles + o.cycles, self.instructions + o.instructions)

    def __truediv__(self, count: Int) -> Self:
        return Self(self.cycles // count, self.instructions // count)

    def min(self, o: Self) -> Self:
        return Self(
            min(self.cycles, o.cycles), min(self.instructions, o.instructions)
        )

    def max(self, o: Self) -> Self:
        return Self(
            max(self.cycles, o.cycles), max(self.instructions, o.instructions)
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.cycles, " cycles, ", self.instructions, " insns")

    def fields(self) -> List[MetricField]:
        return [
            MetricField("cycles", String(self.cycles), Float64(self.cycles)),
            MetricField(
                "instructions",
                String(self.instructions),
                Float64(self.instructions),
            ),
        ]


struct FakePmu(Instrument):
    comptime MetricType = Counters
    var ticks: Int

    def __init__(out self):
        self.ticks = 0

    def measure(mut self) -> Counters:
        self.ticks += 1
        return Counters(self.ticks * 100, self.ticks * 250)


struct Ticker(Instrument):
    comptime MetricType = Nanos
    var now: Int

    def __init__(out self):
        self.now = 0

    def measure(mut self) -> Nanos:
        self.now += 1
        return Nanos(self.now)


def _rows_under(text: String, title: String) raises -> List[String]:
    """Returns the zone rows of the table titled `title`."""
    var lines = text.splitlines()

    var i = 0
    while i < len(lines) and String(lines[i]) != title:
        i += 1
    if i == len(lines):
        raise Error("no table titled ", title)

    while i < len(lines) and not lines[i].startswith("----"):
        i += 1
    if i == len(lines):
        raise Error("table has no header rule: ", title)

    var rows = List[String]()
    for j in range(i + 1, len(lines)):
        if not lines[j]:
            break
        rows.append(String(lines[j]))
    return rows^


# ===----------------------------------------------------------------------=== #
# Single-valued metrics
# ===----------------------------------------------------------------------=== #


def test_scalar_metric_renders_a_single_table() raises:
    comptime Prof = Profiler[Ticker, Tag="test.report.scalar"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var out = String(Prof.report())
    assert_true(out.startswith("Program total: 3ns\n\n"))
    assert_equal(len(Prof.report().tables()), 1)

    var rows = _rows_under(out, "Program total: 3ns")
    assert_equal(len(rows), 1)
    assert_true(rows[0].startswith("work"))
    assert_true(rows[0].find("1ns") != -1)


# ===----------------------------------------------------------------------=== #
# Multi-valued metrics
# ===----------------------------------------------------------------------=== #


def test_each_component_gets_its_own_table() raises:
    comptime Prof = Profiler[FakePmu, Tag="test.report.vector"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.tables()), 2)

    # Four samples are taken (start, open, close, end), so the session spans
    # three steps: 300 cycles and 750 instructions.
    var out = String(rep)
    assert_true(out.startswith("cycles — total 300\n\n"))
    assert_true(out.find("instructions — total 750\n\n") != -1)


def test_a_component_table_holds_only_its_own_values() raises:
    comptime Prof = Profiler[FakePmu, Tag="test.report.vector-values"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var out = String(Prof.report())

    var cycles = _rows_under(out, "cycles — total 300")
    assert_equal(len(cycles), 1)
    assert_true(cycles[0].startswith("work"))
    assert_true(cycles[0].find("100") != -1)
    assert_true(cycles[0].find("250") == -1)

    var instructions = _rows_under(out, "instructions — total 750")
    assert_true(instructions[0].find("250") != -1)
    assert_true(instructions[0].find("100") == -1)


def test_every_zone_appears_in_every_component_table() raises:
    comptime Prof = Profiler[FakePmu, Tag="test.report.vector-zones"]

    Prof.start()
    with Prof.zone["outer"]():
        with Prof.zone["inner"]():
            pass
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.zones), 2)

    var out = String(rep)
    for table in rep.tables():
        var rows = _rows_under(out, table.title)
        assert_equal(len(rows), 2)
        assert_true(rows[0].startswith("outer"))
        assert_true(rows[1].startswith("inner"))


def test_percentages_are_computed_per_component() raises:
    comptime Prof = Profiler[FakePmu, Tag="test.report.vector-percent"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var out = String(Prof.report())
    # 100 of 300 cycles and 250 of 750 instructions: both a third.
    assert_true(_rows_under(out, "cycles — total 300")[0].endswith("33.3%"))
    assert_true(
        _rows_under(out, "instructions — total 750")[0].endswith("33.3%")
    )


# ===----------------------------------------------------------------------=== #
# Customisation
# ===----------------------------------------------------------------------=== #


def test_report_tables_are_restylable() raises:
    comptime Prof = Profiler[Ticker, Tag="test.report.restyle"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var table = Prof.report().tables()[0].copy()
    table.style.gap = " | "
    table.style.color = ColorMode.NEVER
    table.style.rule_char = "="

    var out = String(table)
    assert_true(out.find(" | ") != -1)
    assert_true(out.find("=====") != -1)
    assert_true(out.find("\033[") == -1)


def test_report_table_columns_are_inspectable() raises:
    comptime Prof = Profiler[FakePmu, Tag="test.report.columns"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var tables = Prof.report().tables()
    assert_equal(len(tables[0].columns), 7)
    assert_equal(tables[0].columns[0].header, "Zone")
    assert_equal(tables[0].columns[3].header, "Inclusive")
    assert_true(tables[0].columns[3].align == Align.RIGHT)


def test_empty_report_says_so() raises:
    comptime Prof = Profiler[Ticker, Tag="test.report.empty"]

    Prof.start()
    Prof.end()

    var out = String(Prof.report())
    assert_true(out.find("(no zones recorded)") != -1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
