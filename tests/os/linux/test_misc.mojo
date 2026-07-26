from std.testing import TestSuite, assert_equal, assert_false, assert_true

from professor.os.linux.misc import PerfRecordMisc


def test_cpu_mode_ignores_record_flags() raises:
    var misc = PerfRecordMisc(
        PerfRecordMisc.GuestKernel.value
        | PerfRecordMisc.ProcMapParseTimeout.value
        | PerfRecordMisc.ExactIp.value
    )

    assert_equal(misc.cpu_mode(), PerfRecordMisc.GuestKernel)


def test_record_flags_are_detected_independently_of_cpu_mode() raises:
    var misc = PerfRecordMisc(
        PerfRecordMisc.User.value
        | PerfRecordMisc.ProcMapParseTimeout.value
        | PerfRecordMisc.MmapData.value
    )

    assert_true(misc.has_flag(PerfRecordMisc.ProcMapParseTimeout))
    assert_true(misc.has_flag(PerfRecordMisc.MmapData))
    assert_false(misc.has_flag(PerfRecordMisc.ExactIp))


def test_cpu_modes_are_not_flags() raises:
    var misc = PerfRecordMisc.User

    assert_false(misc.has_flag(PerfRecordMisc.CpuModeUnknown))
    assert_false(misc.has_flag(PerfRecordMisc.User))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
