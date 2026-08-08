from std.sys import stdout
from std.time import perf_counter_ns

from .measure import DataSizeUnit, Instrument, TimeUnit
from .measure.instrument import (
    MetricComponent,
    _MetricInner,
    MType,
    _metric_any_less,
)
from .report.table import Align, Cell, Column, Table, TableStyle

# ===------------------------------------------------------------------------===
# Repetition Test Results
# ===------------------------------------------------------------------------===


struct RepetitionResults[M: _MetricInner](Copyable):
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

    @staticmethod
    def _from_batch(var total: Self.M, repetitions: Int) -> Self:
        var sample = total.div(UInt64(repetitions))
        var results = Self(sample)
        results.test_count = repetitions
        results.total = total^
        return results^

    def _observe(
        mut self, var total: Self.M, repetitions: Int = 1
    ) raises -> Bool:
        var sample = total.div(UInt64(repetitions))
        var improved = _metric_any_less(self.minimum, sample)
        self.test_count += repetitions
        self.total = self.total.add(total)
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

    def update[M: _MetricInner](mut self, results: RepetitionResults[M]) raises:
        if not self._is_terminal:
            return
        self._redraw(self._live_text(results))

    def tick[M: _MetricInner](mut self, results: RepetitionResults[M]) raises:
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

    def finish[M: _MetricInner](mut self, results: RepetitionResults[M]) raises:
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
        M: _MetricInner
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
    var _batch_reps: Int
    var _max_reps: Optional[Int]

    def __init__(
        out self,
        var instrument: Self.I,
        *,
        patience: Int = 10,
        batch_reps: Int = 1,
        max_reps: Optional[Int] = 100,
    ) raises:
        if patience <= 0:
            raise Error("patience must be greater than zero")
        if batch_reps <= 0:
            raise Error("batch_reps must be greater than zero")
        if max_reps and max_reps.value() <= 0:
            raise Error("max_reps must be greater than zero")

        self._instrument = instrument^
        self._patience = patience
        self._batch_reps = batch_reps
        self._max_reps = max_reps

    def run(
        mut self, f: Some[def() raises]
    ) raises -> RepetitionResults[Self.MetricType]:
        """Measures `f` until its minima stop improving."""
        var renderer = _LiveReport()
        renderer.start()

        try:
            var first_batch_reps = self._next_batch_reps(0)
            var first_total = self._measure(f, first_batch_reps)
            var results = RepetitionResults[Self.MetricType]._from_batch(
                first_total^, first_batch_reps
            )
            var stale_repetitions = 0
            renderer.update(results)

            while (
                stale_repetitions < self._patience
                and not self._reached_limit(results.test_count)
            ):
                var repetitions = min(
                    self._next_batch_reps(results.test_count),
                    self._patience - stale_repetitions,
                )
                var total = self._measure(f, repetitions)
                if results._observe(total^, repetitions):
                    stale_repetitions = 0
                    renderer.update(results)
                else:
                    stale_repetitions += repetitions
                    renderer.tick(results)

            renderer.finish(results)
            return results^
        except error:
            renderer.cancel()
            raise error^

    def _measure(
        mut self, f: Some[def() raises], repetitions: Int
    ) raises -> Self.MetricType:
        var start = self._instrument.measure()
        try:
            for _ in range(repetitions):
                f()
        except error:
            raise Error(String(t"error while repetition testing: {error}"))
        var end = self._instrument.measure()
        return end.sub(start)

    def _next_batch_reps(self, completed_repetitions: Int) -> Int:
        if self._max_reps:
            return min(
                self._batch_reps,
                self._max_reps.value() - completed_repetitions,
            )
        return self._batch_reps

    def _reached_limit(self, total_repetitions: Int) -> Bool:
        if self._max_reps:
            return total_repetitions >= self._max_reps.value()
        return False


def _repetition_table[
    M: _MetricInner
](results: RepetitionResults[M]) raises -> Table:
    var minimum = results.minimum.components()
    var maximum = results.maximum.components()
    var total = results.total.components()

    var columns = List[Column](capacity=len(minimum) + 1)
    columns.append(Column("Statistic"))
    for ref field in minimum:
        columns.append(Column(_component_header(field), align=Align.Right))

    var table = Table(
        _title(results.test_count),
        columns^,
        TableStyle(),
    )
    var minimum_row = List[Cell](capacity=len(minimum) + 1)
    minimum_row.append(Cell("Minimum"))
    for ref field in minimum:
        minimum_row.append(Cell(_component_integer(field)))
    table.add_row(minimum_row^)

    var maximum_row = List[Cell](capacity=len(maximum) + 1)
    maximum_row.append(Cell("Maximum"))
    for ref field in maximum:
        maximum_row.append(Cell(_component_integer(field)))
    table.add_row(maximum_row^)

    var average_row = List[Cell](capacity=len(total) + 1)
    average_row.append(Cell("Average"))
    for ref field in total:
        average_row.append(
            Cell(String(field.canonical_value() / Float64(results.test_count)))
        )
    table.add_row(average_row^)
    return table^


def _title(repetitions: Int) -> String:
    var noun = "repetition" if repetitions == 1 else "repetitions"
    return String(t"Repetition results — {repetitions} {noun}")


def _component_header(field: MetricComponent) -> String:
    var name = field.name.copy() if field.name else String("Value")
    var unit: String
    if field.kind == MType.Time:
        unit = TimeUnit.Nanos.symbol
    elif field.kind == MType.DataSize:
        unit = DataSizeUnit.Byte.symbol
    else:
        unit = field.count_kind.copy()
    if unit:
        return name + " (" + unit + ")"
    return name^


def _component_integer(field: MetricComponent) -> String:
    return String(field.value * field.storage_scale)
