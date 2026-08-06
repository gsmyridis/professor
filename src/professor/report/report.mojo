from professor.measure.instrument import _MetricInner

from ._layout import zone_tables
from .format import ReportFormat
from .stat import ZoneStatistics
from .table import Table


struct Report[M: _MetricInner](Defaultable, Writable):
    """The result of a profiling run: per-site statistics."""

    var total: Self.M
    """Metric for the whole duration of the profiling."""

    var stats: List[ZoneStatistics[Self.M]]
    """Aggregate statistics for each zone."""

    var _format: ReportFormat
    """Numeric formatting captured when the report was constructed."""

    var _tables: List[Table]
    """The laid-out report, built once at construction.

    `Writable.write_to` cannot raise, so everything that can fail -- resolving
    the project root, checking that every reading decomposes the way the total
    does -- happens here, where `Profiler.report()` can propagate it. Writing
    the report is then pure rendering, and costs the same however often it is
    written.
    """

    def __init__(out self):
        """Creates an empty, unrendered report."""
        self.total = Self.M()
        self.stats = List[ZoneStatistics[Self.M]]()
        self._format = ReportFormat()
        self._tables = List[Table]()

    def __init__(out self, var format: ReportFormat):
        """Creates an empty report that retains its requested format."""
        self.total = Self.M()
        self.stats = List[ZoneStatistics[Self.M]]()
        self._format = format^
        self._tables = List[Table]()

    def __init__(
        out self,
        var total: Self.M,
        var stats: List[ZoneStatistics[Self.M]],
        var format: ReportFormat = ReportFormat(),
    ) raises:
        self._tables = zone_tables[Self.M](total, stats, format)
        self.total = total^
        self.stats = stats^
        self._format = format^

    def format(self) -> ReportFormat:
        """Returns the numeric format captured when this report was built."""
        return self._format.copy()

    def tables(self) -> List[Table]:
        """Returns one table per metric component, for restyling before
        rendering.

        A single-valued metric yields one table; a metric that decomposes into
        cycles and retired instructions yields two, each titled with that
        component's program total. Printing the report renders these with the
        default style; take them directly to change the column separator,
        force colors on or off, or append rows of your own.
        """
        return self._tables.copy()

    def write_to(self, mut writer: Some[Writer]):
        for i in range(len(self._tables)):
            if i > 0:
                writer.write("\n")
            self._tables[i].write_to(writer)
