from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    assert_not_equal,
)
from std.testing import TestSuite
from std.sys import CompilationTarget

from professor.apple import kperf_data
from professor.apple.events import KnownEvent
from professor.apple.cpu import Cpu


def test_event_accessors_do_not_crash() raises:
    var db = kperf_data.Database()
    var events = db.events()
    for i in range(len(events)):
        var ev = events[i]
        _ = ev.name()
        _ = ev.alias()
        _ = ev.description()
        _ = ev.is_fixed()
        _ = ev.number()
        _ = ev.mask()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
