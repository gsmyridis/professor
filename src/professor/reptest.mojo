from std.sys import stdout
from std.time import perf_counter_ns

from .measure import Instrument, Metric, MetricField
from .report import Align, Cell, Column, Table, TableStyle


struct RepetitionResults[M: Metric](Copyable):
    """Statistics accumulated across completed repetitions."""

    var test_count: Int
    var total: Self.M
    var minimum: Self.M
    var maximum: Self.M

    def __init__(out self, sample: Self.M):
        self.test_count = 1
        self.total = sample.copy()
        self.minimum = sample.copy()
        self.maximum = sample.copy()

    def average(self) -> Self.M:
        return self.total / self.test_count

    def _observe(mut self, sample: Self.M) raises -> Bool:
        var improved = _has_improvement(self.minimum, sample)
        self.test_count += 1
        self.total = self.total + sample
        self.minimum = self.minimum.min(sample)
        self.maximum = self.maximum.max(sample)
        return improved


struct RepetitionReport[M: Metric](Writable):
    """Rendered result of a repetition test."""

    var results: RepetitionResults[Self.M]
    var _tables: List[Table]

    def __init__(out self, var results: RepetitionResults[Self.M]) raises:
        self._tables = _repetition_tables(results)
        self.results = results^

    def tables(self) -> List[Table]:
        return self._tables.copy()

    def write_to(self, mut writer: Some[Writer]):
        for i in range(len(self._tables)):
            if i > 0:
                writer.write("\n")
            self._tables[i].write_to(writer)


struct _LiveReport:
    """Redraws reports in place on a terminal and prints once to a pipe."""

    var _is_terminal: Bool
    var _rendered_lines: Int
    var _spinner_frame: Int
    var _next_spinner_update_ns: Int

    def __init__(out self):
        self._is_terminal = stdout.isatty()
        self._rendered_lines = 0
        self._spinner_frame = 0
        self._next_spinner_update_ns = 0

    def start(mut self):
        if self._is_terminal:
            self._redraw(self._spinner_line())

    def update[M: Metric](mut self, results: RepetitionResults[M]) raises:
        if not self._is_terminal:
            return
        self._redraw(
            String(RepetitionReport[M](results.copy())) + self._spinner_line()
        )

    def tick(mut self):
        if not self._is_terminal:
            return

        var now = Int(perf_counter_ns())
        if now < self._next_spinner_update_ns:
            return

        # The cursor rests below the spinner after every live redraw.
        print(
            String("\033[1A\033[2K") + self._spinner_line(),
            end="",
        )

    def cancel(mut self):
        if self._is_terminal and self._rendered_lines:
            print("\033[1A\033[2K", end="")
            self._rendered_lines -= 1

    def finish[M: Metric](mut self, results: RepetitionResults[M]) raises:
        var report = RepetitionReport[M](results.copy())
        if self._is_terminal:
            self._redraw(String(report))
        else:
            print(report)

    def _redraw(mut self, text: String):
        if self._rendered_lines:
            print(
                String(t"\033[{self._rendered_lines}A\033[J"),
                end="",
            )
        print(text, end="")
        self._rendered_lines = len(text.splitlines())

    def _spinner_line(mut self) -> String:
        var frame = self._spinner_frame % 4
        self._spinner_frame += 1
        self._next_spinner_update_ns = Int(perf_counter_ns()) + 100_000_000

        if frame == 0:
            return "| Testing...\n"
        if frame == 1:
            return "/ Testing...\n"
        if frame == 2:
            return "- Testing...\n"
        return "\\ Testing...\n"


struct RepetitionTester[I: Instrument, //]:
    """Finds component-wise minima by repeatedly measuring one function."""

    comptime MetricType = Self.I.MetricType

    var _instrument: Self.I
    var _patience: Int
    var _max_repetitions: Optional[Int]

    def __init__(
        out self,
        var instrument: Self.I,
        patience: Int = 10,
        max_repetitions: Optional[Int] = 100,
    ) raises:
        if patience <= 0:
            raise Error("patience must be greater than zero")
        if max_repetitions and max_repetitions.value() <= 0:
            raise Error("max_repetitions must be greater than zero")

        self._instrument = instrument^
        self._patience = patience
        self._max_repetitions = max_repetitions

    def run[
        function: def() thin raises -> None
    ](mut self) raises -> RepetitionReport[Self.MetricType]:
        """Measures `function` until its minima stop improving."""
        var renderer = _LiveReport()
        renderer.start()
        try:
            var first_sample = self._measure[function]()
            var results = RepetitionResults[Self.MetricType](first_sample)
            var stale_repetitions = 0
            renderer.update(results)

            while (
                stale_repetitions < self._patience
                and not self._reached_limit(results.test_count)
            ):
                var sample = self._measure[function]()
                if results._observe(sample):
                    stale_repetitions = 0
                    renderer.update(results)
                else:
                    stale_repetitions += 1
                    renderer.tick()

            renderer.finish(results)
            return RepetitionReport[Self.MetricType](results^)
        except:
            renderer.cancel()
            raise

    def _measure[
        function: def() thin raises -> None
    ](mut self) raises -> Self.MetricType:
        var start = self._instrument.measure()
        try:
            function()
        except error:
            raise Error(String(t"error while repetition testing: {error}"))
        var end = self._instrument.measure()
        var sample = end - start
        _require_comparable(sample)
        return sample^

    def _reached_limit(self, total_repetitions: Int) -> Bool:
        if self._max_repetitions:
            return total_repetitions >= self._max_repetitions.value()
        return False


def _repetition_tables[
    M: Metric
](results: RepetitionResults[M]) raises -> List[Table]:
    var minimum = results.minimum.fields()
    var maximum = results.maximum.fields()
    var average = results.average().fields()
    _check_shape(minimum, maximum)
    _check_shape(minimum, average)

    var tables = List[Table](capacity=len(minimum))
    for i in range(len(minimum)):
        var table = Table(
            _title(minimum[i], results.test_count),
            [
                Column("Statistic"),
                Column("Value", align=Align.RIGHT),
            ],
            TableStyle(),
        )
        table.add_row(
            [
                Cell("Minimum"),
                Cell(minimum[i].value.copy()),
            ]
        )
        table.add_row(
            [
                Cell("Maximum"),
                Cell(maximum[i].value.copy()),
            ]
        )
        table.add_row(
            [
                Cell("Average"),
                Cell(average[i].value.copy()),
            ]
        )
        tables.append(table^)
    return tables^


def _title(field: MetricField, repetitions: Int) -> String:
    var noun = "repetition" if repetitions == 1 else "repetitions"
    if field.name:
        return String(t"{field.name} — {repetitions} {noun}")
    return String(t"Repetition results — {repetitions} {noun}")


def _check_shape(lhs: List[MetricField], rhs: List[MetricField]) raises:
    if len(lhs) != len(rhs):
        raise Error("metric field count changed between repetition statistics")
    for i in range(len(lhs)):
        if lhs[i].name != rhs[i].name:
            raise Error("metric field order changed between repetitions")


def _require_comparable[M: Metric](metric: M) raises:
    var fields = metric.fields()
    for ref field in fields:
        if not field.scalar:
            var name = field.name if field.name else String("<unnamed>")
            raise Error(
                "repetition testing requires a scalar value for metric field ",
                name,
            )


def _has_improvement[M: Metric](best: M, candidate: M) raises -> Bool:
    var best_fields = best.fields()
    var candidate_fields = candidate.fields()
    _check_shape(best_fields, candidate_fields)

    var improved = False
    for i in range(len(best_fields)):
        ref best_field = best_fields[i]
        ref candidate_field = candidate_fields[i]
        if not best_field.scalar or not candidate_field.scalar:
            raise Error("repetition testing requires scalar metric fields")
        if candidate_field.scalar.value() < best_field.scalar.value():
            improved = True
    return improved
