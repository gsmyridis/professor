from std.reflection import SourceLocation
from std.testing import assert_equal, assert_true, TestSuite

from professor import (
    Count,
    CountUnit,
    DataSize,
    GlobalProfiler,
    Instrument,
    Metric,
    Nanos,
    Report,
    ReportFormat,
    Time,
    TimeUnit,
)
from professor.measure.instrument import _MetricInner
from professor.report import ZoneStatistics
from professor.report.table import Align, ColorMode


@fieldwise_init
struct Counters(Metric):
    var cycles: Count["cycles"]
    var instructions: Count["instructions"]


struct FakePmu(Instrument):
    comptime MetricType = Counters
    var ticks: UInt64

    def __init__(out self):
        self.ticks = 0

    def measure(mut self) -> Counters:
        self.ticks += 1
        return Counters(
            Count["cycles"](self.ticks * 100),
            Count["instructions"](self.ticks * 250),
        )


struct Ticker(Instrument):
    comptime MetricType = Nanos
    var now: UInt64

    def __init__(out self):
        self.now = 0

    def measure(mut self) -> Nanos:
        self.now += 1
        return Nanos(self.now)


@fieldwise_init
struct TimedFaults(Metric):
    var elapsed: Time[TimeUnit.Micros]
    var faults: Count["page-faults"]


struct TimedFaultTicker(Instrument):
    comptime MetricType = TimedFaults
    var now: UInt64

    def __init__(out self):
        self.now = 0

    def measure(mut self) -> TimedFaults:
        self.now += 1
        return TimedFaults(
            Time[TimeUnit.Micros](self.now),
            Count["page-faults"](self.now * 2),
        )


@fieldwise_init
struct DualTime(Metric):
    var frontend: Time[TimeUnit.Micros]
    var backend: Time[TimeUnit.Millis]


struct DualTimeTicker(Instrument):
    comptime MetricType = DualTime
    var now: UInt64

    def __init__(out self):
        self.now = 0

    def measure(mut self) -> DualTime:
        self.now += 1
        return DualTime(
            Time[TimeUnit.Micros](self.now),
            Time[TimeUnit.Millis](self.now * 2),
        )


comptime MinimumProf = GlobalProfiler[Ticker, Tag="test.report.minimums"]


def _record_minimum_span(children: Int):
    var target = MinimumProf.zone["target"]()
    for _ in range(children):
        with MinimumProf.zone["child"]():
            pass
    target^.close()


def _plain[S: _MetricInner](rep: Report[S]) raises -> String:
    var out = String()
    var tables = rep.tables()
    for i in range(len(tables)):
        if i > 0:
            out += "\n"
        tables[i].style.color = ColorMode.Never
        out += String(tables[i])
    return out^


def _rows_under(text: String, title: String) raises -> List[String]:
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


def _loc() -> SourceLocation:
    return SourceLocation(1, 1, "tests/report/test_report.mojo")


# ===----------------------------------------------------------------------=== #
# Scalar and compound metrics
# ===----------------------------------------------------------------------=== #


def test_scalar_metric_renders_a_single_table() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.report.scalar"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var out = _plain(Prof.report())
    assert_true(out.startswith("Program total: 3 ns\n\n"))
    assert_equal(len(Prof.report().tables()), 1)
    assert_equal(Prof.report().tables()[0].column(3).header, "Inclusive (ns)")

    var rows = _rows_under(out, "Program total: 3 ns")
    assert_equal(len(rows), 1)
    assert_true(rows[0].startswith("work"))


def test_minimum_and_average_columns_use_report_time_values() raises:
    MinimumProf.start()
    _record_minimum_span(3)
    _record_minimum_span(1)
    MinimumProf.end()

    var table = MinimumProf.report().tables()[0].copy()
    table.style.color = ColorMode.Never
    table.style.gap = "|"

    var target_row = String()
    for line in String(table).splitlines():
        if line.startswith("target"):
            target_row = String(line)
            break

    var cells = target_row.split("|")
    assert_equal(len(cells), 9)
    assert_equal(String(cells[2].strip()), "2")
    assert_equal(String(cells[3].strip()), "10")
    assert_equal(String(cells[4].strip()), "6")
    assert_equal(String(cells[5].strip()), "3")
    assert_equal(String(cells[6].strip()), "5")


def test_each_scalar_field_gets_its_own_table() raises:
    comptime Prof = GlobalProfiler[FakePmu, Tag="test.report.vector"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var rep = Prof.report()
    assert_equal(len(rep.tables()), 2)
    var out = _plain(rep)
    assert_true(out.startswith("cycles - total 300 cycles\n\n"))
    assert_true(out.find("instructions - total 750 instructions\n\n") != -1)


def test_count_kind_is_named_by_the_title_not_every_column() raises:
    comptime Prof = GlobalProfiler[FakePmu, Tag="test.report.identities"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var tables = Prof.report().tables()
    assert_equal(tables[0].title, "cycles - total 300 cycles")
    assert_equal(tables[0].column(3).header, "Inclusive")
    assert_equal(tables[1].title, "instructions - total 750 instructions")
    assert_equal(tables[1].column(3).header, "Inclusive")


def test_every_zone_appears_in_every_component_table() raises:
    comptime Prof = GlobalProfiler[FakePmu, Tag="test.report.vector-zones"]

    Prof.start()
    with Prof.zone["outer"]():
        with Prof.zone["inner"]():
            pass
    Prof.end()

    var rep = Prof.report()
    var out = _plain(rep)
    for table in rep.tables():
        var rows = _rows_under(out, table.title)
        assert_equal(len(rows), 2)
        assert_true(rows[0].startswith("outer"))
        assert_true(rows[1].startswith("inner"))


def test_percentages_are_computed_per_component() raises:
    comptime Prof = GlobalProfiler[FakePmu, Tag="test.report.vector-percent"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var out = _plain(Prof.report())
    assert_true(
        _rows_under(out, "cycles - total 300 cycles")[0].endswith("33.3%")
    )
    assert_true(
        _rows_under(out, "instructions - total 750 instructions")[0].endswith(
            "33.3%"
        )
    )


# ===----------------------------------------------------------------------=== #
# Workload and throughput
# ===----------------------------------------------------------------------=== #


def test_processed_data_is_on_every_table_but_throughput_only_time() raises:
    comptime Prof = GlobalProfiler[
        TimedFaultTicker, Tag="test.report.typed-throughput"
    ]

    Prof.start()
    with Prof.zone["work"](bytes=UInt64(2_000)):
        pass
    Prof.end()

    var tables = Prof.report().tables()
    assert_equal(len(tables), 2)
    assert_equal(tables[0].num_columns(), 11)
    assert_equal(tables[0].column(7).header, "Processed Data (kB)")
    assert_equal(tables[0].column(8).header, "Throughput (GB/s)")
    assert_equal(tables[1].num_columns(), 10)
    assert_equal(tables[1].column(7).header, "Processed Data (kB)")
    assert_equal(tables[1].column(8).header, "Inclusive (%)")

    tables[0].style.color = ColorMode.Never
    tables[0].style.gap = "|"
    var lines = String(tables[0]).splitlines()
    var cells = lines[len(lines) - 1].split("|")
    assert_equal(String(cells[7].strip()), "2")
    assert_equal(String(cells[8].strip()), "2")


def test_multiple_time_fields_each_receive_throughput() raises:
    comptime Prof = GlobalProfiler[
        DualTimeTicker, Tag="test.report.dual-time-throughput"
    ]

    Prof.start()
    with Prof.zone["work"](bytes=UInt64(1_000)):
        pass
    Prof.end()

    var tables = Prof.report().tables()
    assert_equal(len(tables), 2)
    assert_true(tables[0].column(8).header.startswith("Throughput"))
    assert_true(tables[1].column(8).header.startswith("Throughput"))


def test_ordinary_rows_show_na_when_any_site_has_workload() raises:
    var stats = [
        ZoneStatistics[Nanos](
            "ordinary", _loc(), 1, Nanos(1), Nanos(1), Nanos(1), None
        ),
        ZoneStatistics[Nanos](
            "work",
            _loc(),
            1,
            Nanos(1),
            Nanos(1),
            Nanos(1),
            DataSize[](10),
        ),
    ]
    var table = Report[Nanos](Nanos(2), stats^).tables()[0].copy()
    table.style.color = ColorMode.Never
    table.style.gap = "|"
    var lines = String(table).splitlines()
    var ordinary = lines[len(lines) - 2].split("|")
    assert_equal(String(ordinary[7].strip()), "N/A")
    assert_equal(String(ordinary[8].strip()), "N/A")


def test_zero_elapsed_is_na_and_zero_bytes_is_zero_rate() raises:
    var stats = [
        ZoneStatistics[Nanos](
            "zero-time",
            _loc(),
            1,
            Nanos(0),
            Nanos(0),
            Nanos(0),
            DataSize[](5),
        ),
        ZoneStatistics[Nanos](
            "zero-bytes",
            _loc(),
            1,
            Nanos(1),
            Nanos(1),
            Nanos(1),
            DataSize[](0),
        ),
        ZoneStatistics[Nanos](
            "real",
            _loc(),
            1,
            Nanos(1_000),
            Nanos(1_000),
            Nanos(1_000),
            DataSize[](2_000),
        ),
    ]
    var table = Report[Nanos](Nanos(1_000), stats^).tables()[0].copy()
    # A zero-elapsed zone divides to infinity unless it is skipped, which would
    # drag the whole column to the top of the unit ladder.
    assert_equal(table.column(8).header, "Throughput (GB/s)")

    table.style.color = ColorMode.Never
    table.style.gap = "|"
    var lines = String(table).splitlines()
    var zero_time = lines[len(lines) - 3].split("|")
    var zero_bytes = lines[len(lines) - 2].split("|")
    var real = lines[len(lines) - 1].split("|")
    assert_equal(String(zero_time[8].strip()), "N/A")
    assert_equal(String(zero_bytes[8].strip()), "0")
    assert_equal(String(real[8].strip()), "2")


# ===----------------------------------------------------------------------=== #
# Formatting and display units
# ===----------------------------------------------------------------------=== #


def test_each_numeric_column_uses_one_unit_selected_from_its_maximum() raises:
    var stats = [
        ZoneStatistics[Nanos](
            "a", _loc(), 1, Nanos(2_000), Nanos(2_000), Nanos(2_000), None
        ),
        ZoneStatistics[Nanos](
            "b", _loc(), 1, Nanos(4_000), Nanos(4_000), Nanos(4_000), None
        ),
        ZoneStatistics[Nanos](
            "c", _loc(), 1, Nanos(10_000), Nanos(10_000), Nanos(10_000), None
        ),
    ]
    var table = Report[Nanos](Nanos(20_000), stats^).tables()[0].copy()
    assert_equal(table.column(3).header, "Inclusive (us)")
    table.style.color = ColorMode.Never
    table.style.gap = "|"
    var lines = String(table).splitlines()
    assert_equal(String(lines[len(lines) - 3].split("|")[3].strip()), "2")
    assert_equal(String(lines[len(lines) - 2].split("|")[3].strip()), "4")
    assert_equal(String(lines[len(lines) - 1].split("|")[3].strip()), "10")


def test_scaled_count_column_shows_only_the_si_prefix() raises:
    comptime Instructions = Count["instructions"]
    var stats = [
        ZoneStatistics[Instructions](
            "a",
            _loc(),
            1,
            Instructions(2_000),
            Instructions(2_000),
            Instructions(2_000),
            None,
        )
    ]
    var report = Report[Instructions](Instructions(2_000), stats^)
    var table = report.tables()[0].copy()
    assert_equal(table.title, "instructions - total 2 k instructions")
    assert_equal(table.column(3).header, "Inclusive (k)")
    assert_equal(table.column(6).header, "Inclusive/Iter (k)")


def test_maximum_decimals_is_report_owned() raises:
    var stats = [
        ZoneStatistics[Nanos](
            "many",
            _loc(),
            1_234,
            Nanos(1_234),
            Nanos(1_234),
            Nanos(1_234),
            None,
        )
    ]
    var default_report = Report[Nanos](Nanos(2_000), stats.copy())
    var custom_report = Report[Nanos](
        Nanos(2_000), stats^, ReportFormat(max_decimals=3)
    )
    # Both group thousands with `,` and separate decimals with `.`; only the
    # retained decimal count is configurable.
    assert_true(_plain(default_report).find("1,234") != -1)
    assert_true(_plain(custom_report).find("1,234") != -1)
    assert_true(_plain(default_report).find("1.23") != -1)
    assert_true(_plain(default_report).find("1.234") == -1)
    assert_true(_plain(custom_report).find("1.234") != -1)


def test_nonzero_value_below_the_last_decimal_renders_zero() raises:
    var stats = [
        ZoneStatistics[Nanos](
            "tiny", _loc(), 1, Nanos(1), Nanos(1), Nanos(1), None
        ),
        ZoneStatistics[Nanos](
            "large",
            _loc(),
            1,
            Nanos(1_000_000_000),
            Nanos(1_000_000_000),
            Nanos(1_000_000_000),
            None,
        ),
    ]
    var report = Report[Nanos](Nanos(1_000_000_001), stats^)
    var table = report.tables()[0].copy()
    table.style.color = ColorMode.Never
    table.style.gap = "|"
    assert_equal(table.column(3).header, "Inclusive (s)")

    var lines = String(table).splitlines()
    assert_equal(String(lines[len(lines) - 2].split("|")[3].strip()), "0")
    assert_equal(String(lines[len(lines) - 1].split("|")[3].strip()), "1")


def test_integral_values_above_float_precision_retain_every_digit() raises:
    var total = Count["events", CountUnit.Billion](UInt64.MAX)
    var out = _plain(Report[type_of(total)](total, []))
    assert_true(
        out.startswith(
            "events - total 18,446,744,073,709,551,615 Bil events\n\n"
        )
    )


# ===----------------------------------------------------------------------=== #
# Table access
# ===----------------------------------------------------------------------=== #


def test_report_tables_are_restylable() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.report.restyle"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var table = Prof.report().tables()[0].copy()
    table.style.gap = " | "
    table.style.color = ColorMode.Never
    table.style.rule_char = "="
    var out = String(table)
    assert_true(out.find(" | ") != -1)
    assert_true(out.find("=====") != -1)
    assert_true(out.find("\033[") == -1)


def test_report_table_columns_are_inspectable() raises:
    comptime Prof = GlobalProfiler[FakePmu, Tag="test.report.columns"]

    Prof.start()
    with Prof.zone["work"]():
        pass
    Prof.end()

    var table = Prof.report().tables()[0].copy()
    assert_equal(table.num_columns(), 9)
    assert_equal(table.column(0).header, "Zone")
    assert_equal(table.column(3).header, "Inclusive")
    assert_equal(table.column(5).header, "Min. Inclusive")
    assert_equal(table.column(6).header, "Inclusive/Iter")
    assert_equal(table.column(7).header, "Inclusive (%)")
    assert_equal(table.column(8).header, "Exclusive (%)")
    assert_true(table.column(3).align == Align.Right)


def test_empty_report_says_so() raises:
    comptime Prof = GlobalProfiler[Ticker, Tag="test.report.empty"]

    Prof.start()
    Prof.end()

    assert_true(_plain(Prof.report()).find("(no zones recorded)") != -1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
