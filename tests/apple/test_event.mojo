from std.testing import (
    assert_equal,
    assert_true,
)
from std.testing import TestSuite

from professor.apple.database import Database


def test_event_accessors_do_not_crash() raises:
    var db = Database()
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
