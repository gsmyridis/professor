from professor.measure import Metric

from ._stat import ZoneStat
from ._tabwriter import _TabWriter


struct Report[S: Metric](Writable):
    """The result of a profiling run: per-site statistics."""

    var total: Self.S
    var zones: List[ZoneStat[Self.S]]

    def __init__(
        out self, var total: Self.S, var zones: List[ZoneStat[Self.S]]
    ):
        self.total = total^
        self.zones = zones^

    def write_to(self, mut writer: Some[Writer]):
        var table = _TabWriter[Self.S](self.total.copy(), self.zones.copy())
        table.write_to(writer)
