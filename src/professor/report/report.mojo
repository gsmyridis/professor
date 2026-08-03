from professor.measure import Metric

from ._layout import zone_tables
from .stat import ZoneStat
from .table import Table


struct Report[S: Metric](Writable):
    """The result of a profiling run: per-site statistics."""

    var total: Self.S
    var zones: List[ZoneStat[Self.S]]

    var _tables: List[Table]
    """The laid-out report, built once at construction.

    `Writable.write_to` cannot raise, so everything that can fail -- resolving
    the project root, checking that every reading decomposes the way the total
    does -- happens here, where `Profiler.report()` can propagate it. Writing
    the report is then pure rendering, and costs the same however often it is
    written.
    """

    def __init__(
        out self, var total: Self.S, var zones: List[ZoneStat[Self.S]]
    ) raises:
        self._tables = zone_tables[Self.S](total, zones)
        self.total = total^
        self.zones = zones^

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
