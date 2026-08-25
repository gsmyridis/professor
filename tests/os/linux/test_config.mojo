from std.testing import TestSuite, assert_equal, assert_false, assert_true

from professor.os.linux.event import PerfEvent
from professor.os.linux import (
    CounterConfig,
    CountMode,
    Flag,
    Virtualization,
)


def test_flags_can_be_combined() raises:
    var flags = Flag.CloseOnExec | Flag.ContainerGroup

    assert_equal(
        flags.value,
        Flag.CloseOnExec.value | Flag.ContainerGroup.value,
    )
    assert_true(Flag.CloseOnExec in flags)
    assert_true(Flag.ContainerGroup in flags)
    assert_false(Flag.Output in flags)


def test_counter_configs_are_independent() raises:
    var userspace = CounterConfig(PerfEvent.CpuCycles)
    var system = CounterConfig(
        PerfEvent.Instructions,
        mode=CountMode.Userspace | CountMode.Kernel,
        virtualization=Virtualization.Host | Virtualization.Guest,
        exclude_idle=True,
    )

    assert_equal(userspace.event, PerfEvent.CpuCycles)
    assert_true(CountMode.Userspace in userspace.mode)
    assert_false(CountMode.Kernel in userspace.mode)
    assert_false(userspace.exclude_idle)

    assert_equal(system.event, PerfEvent.Instructions)
    assert_true(CountMode.Userspace in system.mode)
    assert_true(CountMode.Kernel in system.mode)
    assert_true(Virtualization.Host in system.virtualization)
    assert_true(Virtualization.Guest in system.virtualization)
    assert_true(system.exclude_idle)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
