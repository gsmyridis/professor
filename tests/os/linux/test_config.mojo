from std.testing import TestSuite, assert_equal

from professor.os.linux.config import Flag


def test_flags_can_be_combined() raises:
    var flags = Flag.CloseOnExec | Flag.ContainerGroup

    assert_equal(
        flags.value,
        Flag.CloseOnExec.value | Flag.ContainerGroup.value,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
