"""
Run with sudo.
"""

from std.ffi import c_char, c_size_t, c_int
from std.testing import assert_not_equal
from std.memory import alloc, Layout

from professor.apple.ffi import kperf, kperf_data
from professor.apple.ffi.testing import assert_success


def print_counting(get_fn: def() thin -> UInt32):
    var counting = get_fn()
    print("- Get:")
    print("\t- COUNT:", counting)
    print("\t- FIXED:", Bool(counting & kperf.KPC_CLASS_FIXED_MASK))
    print(
        "\t- CONFIGURABLE:",
        Bool(counting & kperf.KPC_CLASS_CONFIGURABLE_MASK),
    )
    print("\t- POWER:", Bool(counting & kperf.KPC_CLASS_POWER_MASK))
    print("\t- RAWPMU:", Bool(counting & kperf.KPC_CLASS_RAWPMU_MASK))


def run_kperf_ffi_example() raises:
    # ===--------------------------------------------------------------------===
    # Get sampler version
    # ===--------------------------------------------------------------------===
    var version = kperf.kpc_pmu_version()
    assert_not_equal(version, kperf.KPC_PMU_ERROR, "failed to read PMU version")
    print("Version:", version)

    # ===--------------------------------------------------------------------===
    # Get CPU string
    # ===--------------------------------------------------------------------===
    var cpu_id_buffer = InlineArray[c_char, 64](fill=0)
    var _ = kperf.kpc_cpu_string(
        cpu_id_buffer.unsafe_ptr(), c_size_t(len(cpu_id_buffer))
    )
    var cpu_id = String(unsafe_from_utf8_ptr=cpu_id_buffer.unsafe_ptr())
    print("CPU string:", cpu_id)

    # ===--------------------------------------------------------------------===
    # Get / Set global counting
    # ===--------------------------------------------------------------------===
    print("Global counting:")
    print_counting(kperf.kpc_get_counting)

    var classes = kperf.KPC_CLASS_FIXED_MASK | kperf.KPC_CLASS_CONFIGURABLE_MASK
    print(t"- Setting classes: {classes}")
    assert_success(kperf.kpc_set_counting(classes))

    print_counting(kperf.kpc_get_counting)

    # ===--------------------------------------------------------------------===
    # Get / Set thread counting
    # ===--------------------------------------------------------------------===
    print("Thread counting:")
    print_counting(kperf.kpc_get_thread_counting)

    var classes_thread = kperf.KPC_CLASS_CONFIGURABLE_MASK
    print(t"- Setting classes: {classes_thread}")
    assert_success(kperf.kpc_set_thread_counting(classes_thread))

    print_counting(kperf.kpc_get_thread_counting)

    # ===--------------------------------------------------------------------===
    # Get counter count
    # ===--------------------------------------------------------------------===
    print("Counter counts:")
    print("\t- Fixed:", kperf.kpc_get_counter_count(kperf.KPC_CLASS_FIXED_MASK))
    print(
        "\t- Configurable:",
        kperf.kpc_get_counter_count(kperf.KPC_CLASS_CONFIGURABLE_MASK),
    )
    print(
        "\t- Fixed or Configurable:",
        kperf.kpc_get_counter_count(
            kperf.KPC_CLASS_FIXED_MASK | kperf.KPC_CLASS_CONFIGURABLE_MASK
        ),
    )

    # ===--------------------------------------------------------------------===
    # Get CPU counters
    # ===--------------------------------------------------------------------===
    print("Getting CPU counters:")
    var counters_cpu_id: c_int = 0
    var cpu_counters_buf = InlineArray[UInt64, 64](fill=0)
    assert_success(
        kperf.kpc_get_cpu_counters(
            False,
            kperf.KPC_CLASS_FIXED_MASK,
            UnsafePointer(to=counters_cpu_id),
            cpu_counters_buf.unsafe_ptr(),
        )
    )
    print("\t- CPU ID:", counters_cpu_id)
    print("\t- Counters:", cpu_counters_buf)

    # ===--------------------------------------------------------------------===
    # Get thread counters
    # ===--------------------------------------------------------------------===
    assert_success(kperf.kpc_set_thread_counting(classes))
    print("Thread counting (after set):")
    print_counting(kperf.kpc_get_thread_counting)

    var thread_counters_buf_len = kperf.kpc_get_counter_count(classes)
    var thread_counters_buf = alloc(
        Layout[UInt64](count=Int(thread_counters_buf_len))
    ).unsafe_leak()
    assert_success(
        kperf.kpc_get_thread_counters(
            0,
            UInt32(thread_counters_buf_len),
            thread_counters_buf,
        )
    )
    print(thread_counters_buf)

    # ===--------------------------------------------------------------------===
    # Force set / get all counters set
    # ===--------------------------------------------------------------------===
    var val: c_int = 0
    print("Forcing all counters to:", val)
    assert_success(kperf.kpc_force_all_ctrs_set(val))

    assert_success(kperf.kpc_force_all_ctrs_get(UnsafePointer(to=val)))
    print("Reading all counters:", val)


    # ===--------------------------------------------------------------------===
    # Config
    # ===--------------------------------------------------------------------===
    var db = kperf_data.KPEPDb.MutPointerType.unsafe_dangling()
    assert_success(kperf_data.kpep_db_create({}, UnsafePointer(to=db)))

    var config = kperf_data.KPEPConfig.MutPointerType.unsafe_dangling()
    assert_success(kperf_data.kpep_config_create(db, UnsafePointer(to=config)))



    kperf_data.kpep_config_free(config)



def main() raises:
    try:
        run_kperf_ffi_example()
    except e:
        print(t"error: {e}")
        print("possible fix: run with sudo")
