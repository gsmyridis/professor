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


def test_counter_configs_are_independent() raises:
    var userspace = CounterConfig(PerfEvent.CpuCycles)
    var system = CounterConfig(
        PerfEvent.Instructions,
        mode=CountMode.Userspace | CountMode.Kernel,
        virtualization=Virtualization.Host | Virtualization.Guest,
        exclude_idle=True,
    )

    assert_equal(userspace.event, PerfEvent.CpuCycles)
    assert_true(userspace.mode.includes(CountMode.Userspace))
    assert_false(userspace.mode.includes(CountMode.Kernel))
    assert_false(userspace.exclude_idle)

    assert_equal(system.event, PerfEvent.Instructions)
    assert_true(system.mode.includes(CountMode.Userspace))
    assert_true(system.mode.includes(CountMode.Kernel))
    assert_true(system.virtualization.includes(Virtualization.Host))
    assert_true(system.virtualization.includes(Virtualization.Guest))
    assert_true(system.exclude_idle)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
