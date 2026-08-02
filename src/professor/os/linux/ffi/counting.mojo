"""Stable read layouts for Linux perf event counting."""


struct PerfEventCountAndTime(Copyable, Defaultable):
    """Single-event read with enabled and running time metadata.

    Use with `PERF_FORMAT_TOTAL_TIME_ENABLED |
    PERF_FORMAT_TOTAL_TIME_RUNNING`.
    """

    var value: UInt64
    var time_enabled: UInt64
    var time_running: UInt64

    def __init__(out self):
        self.value = 0
        self.time_enabled = 0
        self.time_running = 0


struct GroupHeader(Copyable, Defaultable):
    """Header for a group read with enabled and running time metadata.

    Use with `PERF_FORMAT_GROUP | PERF_FORMAT_ID |
    PERF_FORMAT_TOTAL_TIME_ENABLED | PERF_FORMAT_TOTAL_TIME_RUNNING`.
    `nr` entries immediately follow this header.
    """

    var nr: UInt64
    var time_enabled: UInt64
    var time_running: UInt64

    def __init__(out self):
        self.nr = 0
        self.time_enabled = 0
        self.time_running = 0


struct PerfEventGroupReadEntry(Copyable, Defaultable):
    """One value/ID pair following `PerfEventGroupReadHeader`."""

    var value: UInt64
    var id: UInt64

    def __init__(out self):
        self.value = 0
        self.id = 0
