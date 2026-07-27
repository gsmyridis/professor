from professor.measure import Metric

from ._layout import zone_tables
from ._stat import ZoneStat
from ._table import Table


struct Report[S: Metric](Writable):
    """The result of a profiling run: per-site statistics."""

    var total: Self.S
    var zones: List[ZoneStat[Self.S]]

    def __init__(
        out self, var total: Self.S, var zones: List[ZoneStat[Self.S]]
    ):
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
        return zone_tables[Self.S](self.total, self.zones)

    def write_to(self, mut writer: Some[Writer]):
        var tables = self.tables()
        for i in range(len(tables)):
            if i > 0:
                writer.write("\n")
            tables[i].write_to(writer)
