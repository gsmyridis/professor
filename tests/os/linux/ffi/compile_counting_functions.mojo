"""Compile-only coverage for Linux-specific perf event counting calls."""

from std.ffi import c_int, c_size_t, c_ulong

from professor.os.linux._sys import (
    Attributes,
    PERF_IOC_FLAG_GROUP,
    perf_event_disable,
    perf_event_enable,
    perf_event_id,
    perf_event_open,
    perf_event_read,
    perf_event_reset,
)


def main():
    """Instantiate every Linux counting wrapper for compile-time coverage."""
    var attr = Attributes()
    var id: UInt64 = 0
    var values: UInt64 = 0

    var fd = perf_event_open(
        UnsafePointer(to=attr),
        c_int(0),
        c_int(-1),
        c_int(-1),
        c_ulong(0),
    )
    _ = perf_event_id(fd, UnsafePointer(to=id))
    _ = perf_event_read(fd, UnsafePointer(to=values), c_size_t(1))
    _ = perf_event_enable(fd, PERF_IOC_FLAG_GROUP)
    _ = perf_event_disable(fd, PERF_IOC_FLAG_GROUP)
    _ = perf_event_reset(fd, PERF_IOC_FLAG_GROUP)
