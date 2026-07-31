from std.testing import TestSuite, assert_true

from professor.arch.x86 import rdtsc, rdtscp


def test_rdtsc_is_monotonic() raises:
    var tsc_0 = rdtsc()
    var tsc_1 = rdtsc()

    assert_true(tsc_1 > tsc_0, "rdtsc is not monotonic")


def test_rdtscp_is_monotonic() raises:
    var tsc_0 = rdtscp()
    var tsc_1 = rdtscp()

    assert_true(tsc_1 > tsc_0, "rdtscp is not monotonic")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
