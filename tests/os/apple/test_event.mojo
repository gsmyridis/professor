from std.testing import (
    assert_equal,
    assert_false,
    assert_true,
)
from std.testing import TestSuite

from professor.os.apple import AppleEvent, Cpu, Database


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


def test_apple_event_availability_uses_cpu_masks() raises:
    assert_true(AppleEvent.FixedCycles.is_available_on(Cpu.M1))
    assert_true(AppleEvent.FixedCycles.is_available_on(Cpu.M5))

    assert_false(AppleEvent.ArmBrMisPred.is_available_on(Cpu.M1))
    assert_false(AppleEvent.ArmBrMisPred.is_available_on(Cpu.M3))
    assert_true(AppleEvent.ArmBrMisPred.is_available_on(Cpu.M4))
    assert_true(AppleEvent.ArmBrMisPred.is_available_on(Cpu.M5))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
