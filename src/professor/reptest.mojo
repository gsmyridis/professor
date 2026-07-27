from std.reflection import SourceLocation
from std.sys import stdout

from .measure import Metric
from .report import Report, ZoneStat
from .profile import ProfilerTrait


struct _RepetitionAggregate[S: Metric]:
    """Cumulative profiler statistics across independent repetitions."""

    var total: Self.S
    var zones: List[ZoneStat[Self.S]]

    def __init__(out self):
        self.total = Self.S()
        self.zones = List[ZoneStat[Self.S]]()

    def observe(mut self, sample: Report[Self.S]) raises -> Bool:
        """Merges one completed profiler session.

        Returns `True` when any component of any zone's inclusive minimum
        strictly improves, or when a zone is observed for the first time.
        """
        var improved = False
        self.total = self.total + sample.total

        for ref candidate in sample.zones:
            _require_comparable(candidate.inclusive_min)
            var index = self._find_zone(candidate)

            if index == -1:
                self.zones.append(candidate.copy())
                improved = True
                continue

            ref best = self.zones[index]
            if _has_improvement(best.inclusive_min, candidate.inclusive_min):
                improved = True

            best.count += candidate.count
            best.inclusive = best.inclusive + candidate.inclusive
            best.exclusive = best.exclusive + candidate.exclusive
            best.inclusive_min = best.inclusive_min.min(candidate.inclusive_min)

        return improved

    def report(self) raises -> Report[Self.S]:
        return Report[Self.S](self.total.copy(), self.zones.copy())

    def _find_zone(self, candidate: ZoneStat[Self.S]) -> Int:
        for i in range(len(self.zones)):
            ref existing = self.zones[i]
            if _same_site(
                existing.name, existing.loc, candidate.name, candidate.loc
            ):
                return i
        return -1


struct _LiveReport:
    """Redraws reports in place on a terminal and prints once to a pipe."""

    var _enabled: Bool
    var _is_terminal: Bool
    var _rendered_lines: Int

    def __init__(out self, enabled: Bool):
        self._enabled = enabled
        self._is_terminal = enabled and stdout.isatty()
        self._rendered_lines = 0

    def update[S: Metric](mut self, report: Report[S]):
        if not self._is_terminal:
            return
        self._redraw(String(report))

    def finish[S: Metric](mut self, report: Report[S]):
        if not self._enabled:
            return
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


struct RepetitionTester[
    profiler: ProfilerTrait,
    //,
    function: def() thin raises -> None,
    *,
    reps: Int = 10,
] where (
    reps > 0
):
    """Runs a function until its profiled minima stop improving.

    `reps` is the number of consecutive repetitions without any new minimum
    required to stop. `max_reps` optionally places a hard limit on the total
    number of function invocations.
    """

    comptime MetricType = Self.profiler.MetricType

    var _max_reps: Optional[Int]
    var _print_results: Bool

    def __init__(
        out self,
        max_reps: Optional[Int] = None,
        *,
        print_results: Bool = True,
    ) raises:
        if max_reps and max_reps.value() <= 0:
            raise Error("max_reps must be greater than zero")
        self._max_reps = max_reps
        self._print_results = print_results

    def run(mut self) raises -> Report[Self.MetricType]:
        var aggregate = _RepetitionAggregate[Self.MetricType]()
        var renderer = _LiveReport(self._print_results)
        var stale_reps = 0
        var total_reps = 0

        while stale_reps < Self.reps and not self._reached_limit(total_reps):
            var session_ended = False
            Self.profiler.start()

            try:
                with Self.profiler.zone["repetition"]():
                    Self.function()

                Self.profiler.end()
                session_ended = True
                var sample = Self.profiler.report()
                var improved = aggregate.observe(sample)
                total_reps += 1

                if improved:
                    stale_reps = 0
                    renderer.update(aggregate.report())
                else:
                    stale_reps += 1

                Self.profiler.reset()
            except error:
                if not session_ended:
                    Self.profiler.end()
                Self.profiler.reset()
                raise Error(String(t"error while repetition testing: {error}"))

        var result = aggregate.report()
        renderer.finish(result)
        return aggregate.report()

    def _reached_limit(self, total_reps: Int) -> Bool:
        if self._max_reps:
            return total_reps >= self._max_reps.value()
        return False


def _same_site(
    lhs_name: StaticString,
    lhs_loc: SourceLocation,
    rhs_name: StaticString,
    rhs_loc: SourceLocation,
) -> Bool:
    return (
        lhs_name == rhs_name
        and lhs_loc.file_name() == rhs_loc.file_name()
        and lhs_loc.line() == rhs_loc.line()
        and lhs_loc.column() == rhs_loc.column()
    )


def _require_comparable[S: Metric](metric: S) raises:
    var fields = metric.fields()
    for ref field in fields:
        if not field.scalar:
            var name = field.name if field.name else String("<unnamed>")
            raise Error(
                "repetition testing requires a scalar value for metric field ",
                name,
            )


def _has_improvement[S: Metric](best: S, candidate: S) raises -> Bool:
    var best_fields = best.fields()
    var candidate_fields = candidate.fields()
    if len(best_fields) != len(candidate_fields):
        raise Error("metric field count changed between repetitions")

    var improved = False
    for i in range(len(best_fields)):
        ref best_field = best_fields[i]
        ref candidate_field = candidate_fields[i]
        if best_field.name != candidate_field.name:
            raise Error("metric field order changed between repetitions")
        if not best_field.scalar or not candidate_field.scalar:
            raise Error("repetition testing requires scalar metric fields")
        if candidate_field.scalar.value() < best_field.scalar.value():
            improved = True
    return improved
