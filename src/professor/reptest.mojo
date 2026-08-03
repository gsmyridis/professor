from std.sys import stdout
from std.time import perf_counter_ns

from .measure import Instrument, Metric, MetricField
from .report.table import Align, Cell, Column, Table, TableStyle


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


struct _LiveReport:
    """Shows terminal activity and prints the completed report once."""

    var _is_terminal: Bool
    var _rendered_lines: Int
    var _spinner_frame: Int
    """Stores the status spiner frame number."""
    var _next_spinner_update_ns: Int

    def __init__(out self):
        self._is_terminal = stdout.isatty()
        self._rendered_lines = 0
        self._spinner_frame = 0
        self._next_spinner_update_ns = 0

    def start(mut self):
        if self._is_terminal:
            self._redraw(self._status_line())

    def update[M: Metric](mut self, results: RepetitionResults[M]) raises:
        if not self._is_terminal:
            return
        self._redraw(self._live_text(results))

    def tick[M: Metric](mut self, results: RepetitionResults[M]) raises:
        if not self._is_terminal:
            return

        var now = Int(perf_counter_ns())
        if now < self._next_spinner_update_ns:
            return

        self._redraw(self._live_text(results))

    def cancel(mut self):
        if self._is_terminal and self._rendered_lines:
            _clear_terminal(self._rendered_lines)
            self._rendered_lines = 0

    def finish[M: Metric](mut self, results: RepetitionResults[M]) raises:
        var table = _repetition_table(results)
        if self._is_terminal:
            self._redraw(String(table))
        else:
            print(table)

    def _redraw(mut self, text: String):
        if self._rendered_lines:
            _clear_terminal(self._rendered_lines)
        print(text, end="")
        self._rendered_lines = len(text.splitlines())

    def _live_text[
        M: Metric
    ](mut self, results: RepetitionResults[M]) raises -> String:
        var table = _repetition_table(results)
        table.title = self._status()
        return String(table)

    def _status_line(mut self) -> String:
        return self._status() + "\n"

    def _status(mut self) -> String:
        var frame = self._spinner_frame % 8
        self._spinner_frame += 1
        self._next_spinner_update_ns = Int(perf_counter_ns()) + 100_000_000

        if frame == 0:
            return "⣾ Testing"
        if frame == 1:
            return "⣷ Testing"
        if frame == 2:
            return "⣯ Testing"
        if frame == 3:
            return "⣟ Testing"
        if frame == 4:
            return "⡿ Testing"
        if frame == 5:
            return "⢿ Testing"
        if frame == 6:
            return "⣽ Testing"
        return "⣻ Testing"


def _clear_terminal(n_lines: Int):
    """Clears the `n_lines` last lines from the terminal."""
    comptime MOVE_CURSOR = "\033["
    comptime UP = "A"
    comptime CLEAR_DISPLAY_TILL_END = "\033[J"

    print(
        t"{MOVE_CURSOR}{n_lines}{UP}{CLEAR_DISPLAY_TILL_END}",
        end="",
    )


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
    ](mut self) raises -> RepetitionResults[Self.MetricType]:
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
                    renderer.tick(results)

            renderer.finish(results)
            return results^
        except error:
            renderer.cancel()
            raise error^

    def _measure[
        function: def() thin raises -> None
    ](mut self) raises -> Self.MetricType:
        var start = self._instrument.measure()
        try:
            function()
        except error:
            raise Error(String(t"error while repetition testing: {error}"))
        var end = self._instrument.measure()
        var delta = end - start
        _require_comparable(delta)
        return delta^

    def _reached_limit(self, total_repetitions: Int) -> Bool:
        if self._max_repetitions:
            return total_repetitions >= self._max_repetitions.value()
        return False


def _repetition_table[M: Metric](results: RepetitionResults[M]) raises -> Table:
    var minimum = results.minimum.fields()
    var maximum = results.maximum.fields()
    var average = results.average().fields()
    _check_shape(minimum, maximum)
    _check_shape(minimum, average)

    var columns = List[Column](capacity=len(minimum) + 1)
    columns.append(Column("Statistic"))
    for ref field in minimum:
        if field.name:
            columns.append(Column(field.name.copy(), align=Align.RIGHT))
        else:
            columns.append(Column("Value", align=Align.RIGHT))

    var table = Table(
        _title(results.test_count),
        columns^,
        TableStyle(),
    )
    var minimum_row = List[Cell](capacity=len(minimum) + 1)
    minimum_row.append(Cell("Minimum"))
    for ref field in minimum:
        minimum_row.append(Cell(field.value.copy()))
    table.add_row(minimum_row^)

    var maximum_row = List[Cell](capacity=len(maximum) + 1)
    maximum_row.append(Cell("Maximum"))
    for ref field in maximum:
        maximum_row.append(Cell(field.value.copy()))
    table.add_row(maximum_row^)

    var average_row = List[Cell](capacity=len(average) + 1)
    average_row.append(Cell("Average"))
    for ref field in average:
        average_row.append(Cell(field.value.copy()))
    table.add_row(average_row^)
    return table^


def _title(repetitions: Int) -> String:
    var noun = "repetition" if repetitions == 1 else "repetitions"
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
