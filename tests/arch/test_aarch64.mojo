from std.testing import TestSuite, assert_equal

from professor.arch.aarch64 import cntfrq_el0, cntvct_el0, cntpct_el0


def test_cntfrq_el0_is_constant() raises:
    var freq_0 = cntfrq_el0()
    var freq_1 = cntfrq_el0()
    assert_equal(freq_0, freq_1, "system counter frequency is not constant")


def test_cntvct_el0_is_monotonic() raises:
    var virtual_counter_0 = cntvct_el0()
    var virtual_counter_1 = cntvct_el0()
    assert (
        virtual_counter_1 > virtual_counter_0
    ), "el0 virtual counter is not monotonic"


def test_cntpct_el0_is_monotonic() raises:
    var physical_counter_0 = cntpct_el0()
    var physical_counter_1 = cntpct_el0()
    assert (
        physical_counter_1 > physical_counter_0
    ), "el0 physical counter is not monotonic"


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
