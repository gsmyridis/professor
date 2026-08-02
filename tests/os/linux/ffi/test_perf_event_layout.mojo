from std.reflection import reflect
from std.sys import size_of
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from professor.os.linux.ffi.attr import (
    PERF_ATTR_SIZE_VER9,
    PERF_COUNT_HW_CACHE_BPU,
    PERF_COUNT_HW_CACHE_DTLB,
    PERF_COUNT_HW_CACHE_ITLB,
    PERF_COUNT_HW_CACHE_L1D,
    PERF_COUNT_HW_CACHE_L1I,
    PERF_COUNT_HW_CACHE_LL,
    PERF_COUNT_HW_CACHE_MAX,
    PERF_COUNT_HW_CACHE_NODE,
    PERF_COUNT_HW_CACHE_OP_MAX,
    PERF_COUNT_HW_CACHE_OP_PREFETCH,
    PERF_COUNT_HW_CACHE_OP_READ,
    PERF_COUNT_HW_CACHE_OP_WRITE,
    PERF_COUNT_HW_CACHE_RESULT_ACCESS,
    PERF_COUNT_HW_CACHE_RESULT_MAX,
    PERF_COUNT_HW_CACHE_RESULT_MISS,
    PERF_COUNT_HW_CPU_CYCLES,
    PERF_FORMAT_MAX,
)
from professor.os.linux._sys import (
    PerfEventAttr,
    perf_hardware_cache_config,
    perf_hardware_event_config,
)
from professor.os.linux.ffi.counting import (
    PerfEventCountAndTime,
    PerfEventGroupReadEntry,
    PerfEventGroupReadHeader,
)
from professor.os.linux.ffi.functions import PERF_EVENT_IOC_ID


def test_perf_event_attr_size_and_alignment_sensitive_offsets() raises:
    comptime attr = reflect[PerfEventAttr]

    assert_equal(size_of[PerfEventAttr](), Int(PERF_ATTR_SIZE_VER9))
    assert_equal(attr.field_offset[name="type_"](), 0)
    assert_equal(attr.field_offset[name="size"](), 4)
    assert_equal(attr.field_offset[name="config"](), 8)
    assert_equal(attr.field_offset[name="sample_period_or_freq"](), 16)
    assert_equal(attr.field_offset[name="sample_type"](), 24)
    assert_equal(attr.field_offset[name="read_format"](), 32)
    assert_equal(attr.field_offset[name="flags"](), 40)
    assert_equal(attr.field_offset[name="bp_type"](), 52)
    assert_equal(attr.field_offset[name="config1"](), 56)
    assert_equal(attr.field_offset[name="config2"](), 64)
    assert_equal(attr.field_offset[name="branch_sample_type"](), 72)
    assert_equal(attr.field_offset[name="sample_regs_intr"](), 96)
    assert_equal(attr.field_offset[name="aux_sample_size"](), 112)
    assert_equal(attr.field_offset[name="aux_action"](), 116)
    assert_equal(attr.field_offset[name="sig_data"](), 120)
    assert_equal(attr.field_offset[name="config3"](), 128)
    assert_equal(attr.field_offset[name="config4"](), 136)


def test_perf_event_attr_default_is_zero_except_for_size() raises:
    var attr = PerfEventAttr()

    assert_equal(attr.size, PERF_ATTR_SIZE_VER9)
    assert_equal(attr.type_, 0)
    assert_equal(attr.config, 0)
    assert_equal(attr.flags, 0)
    assert_equal(attr.config3, 0)
    assert_equal(attr.config4, 0)


def test_perf_event_attr_flag_accessors() raises:
    var attr = PerfEventAttr()

    attr.set_disabled()
    attr.set_exclude_kernel()
    attr.set_exclude_hv()

    assert_true(attr.disabled())
    assert_true(attr.exclude_kernel())
    assert_true(attr.exclude_hv())
    assert_false(attr.exclude_user())
    assert_equal(attr.flags, UInt64(0b1100001))

    attr.set_exclude_kernel(False)
    assert_false(attr.exclude_kernel())
    assert_equal(attr.flags, UInt64(0b1000001))


def test_counting_attribute_flag_accessors() raises:
    var attr = PerfEventAttr()

    attr.set_exclude_idle()
    attr.set_inherit_stat()
    attr.set_enable_on_exec()
    attr.set_exclude_host()
    attr.set_exclude_guest()
    attr.set_inherit_thread()
    attr.set_remove_on_exec()

    assert_true(attr.exclude_idle())
    assert_true(attr.inherit_stat())
    assert_true(attr.enable_on_exec())
    assert_true(attr.exclude_host())
    assert_true(attr.exclude_guest())
    assert_true(attr.inherit_thread())
    assert_true(attr.remove_on_exec())
    assert_equal(
        attr.flags,
        (UInt64(1) << 7)
        | (UInt64(1) << 11)
        | (UInt64(1) << 12)
        | (UInt64(1) << 19)
        | (UInt64(1) << 20)
        | (UInt64(1) << 35)
        | (UInt64(1) << 36),
    )

    attr.set_exclude_guest(False)
    attr.set_remove_on_exec(False)
    assert_false(attr.exclude_guest())
    assert_false(attr.remove_on_exec())


def test_hardware_cache_event_constants_and_encoding() raises:
    assert_equal(PERF_COUNT_HW_CACHE_L1D, 0)
    assert_equal(PERF_COUNT_HW_CACHE_L1I, 1)
    assert_equal(PERF_COUNT_HW_CACHE_LL, 2)
    assert_equal(PERF_COUNT_HW_CACHE_DTLB, 3)
    assert_equal(PERF_COUNT_HW_CACHE_ITLB, 4)
    assert_equal(PERF_COUNT_HW_CACHE_BPU, 5)
    assert_equal(PERF_COUNT_HW_CACHE_NODE, 6)
    assert_equal(PERF_COUNT_HW_CACHE_MAX, 7)

    assert_equal(PERF_COUNT_HW_CACHE_OP_READ, 0)
    assert_equal(PERF_COUNT_HW_CACHE_OP_WRITE, 1)
    assert_equal(PERF_COUNT_HW_CACHE_OP_PREFETCH, 2)
    assert_equal(PERF_COUNT_HW_CACHE_OP_MAX, 3)

    assert_equal(PERF_COUNT_HW_CACHE_RESULT_ACCESS, 0)
    assert_equal(PERF_COUNT_HW_CACHE_RESULT_MISS, 1)
    assert_equal(PERF_COUNT_HW_CACHE_RESULT_MAX, 2)

    assert_equal(
        perf_hardware_event_config(PERF_COUNT_HW_CPU_CYCLES),
        PERF_COUNT_HW_CPU_CYCLES,
    )
    assert_equal(
        perf_hardware_event_config(PERF_COUNT_HW_CPU_CYCLES, pmu_type=7),
        UInt64(7) << 32,
    )
    assert_equal(
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
        UInt64(0x10000),
    )
    assert_equal(
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
            pmu_type=5,
        ),
        (UInt64(5) << 32) | UInt64(0x202),
    )


def test_counting_read_layouts() raises:
    comptime single = reflect[PerfEventCountAndTime]
    comptime header = reflect[PerfEventGroupReadHeader]
    comptime entry = reflect[PerfEventGroupReadEntry]

    assert_equal(size_of[PerfEventCountAndTime](), 24)
    assert_equal(single.field_offset[name="value"](), 0)
    assert_equal(single.field_offset[name="time_enabled"](), 8)
    assert_equal(single.field_offset[name="time_running"](), 16)

    assert_equal(size_of[PerfEventGroupReadHeader](), 24)
    assert_equal(header.field_offset[name="nr"](), 0)
    assert_equal(header.field_offset[name="time_enabled"](), 8)
    assert_equal(header.field_offset[name="time_running"](), 16)

    assert_equal(size_of[PerfEventGroupReadEntry](), 16)
    assert_equal(entry.field_offset[name="value"](), 0)
    assert_equal(entry.field_offset[name="id"](), 8)
    assert_equal(PERF_FORMAT_MAX, UInt64(1) << 5)
    assert_equal(PERF_EVENT_IOC_ID, 0x80082407)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
