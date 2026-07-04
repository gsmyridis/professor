from std.ffi import c_char, c_size_t, c_int

from std.testing import assert_equal
from std.memory.alloc import alloc, dealloc, Layout
from std.sys.info import size_of

from professor.apple.ffi import kperf, kperf_data
from professor.apple.ffi.testing import assert_success
from professor.ffi_utils import cstr_to_string, ConstCStringPointer


def print_event_info(
    event: UnsafePointer[kperf_data.KPEPEvent, MutUntrackedOrigin]
) raises:
    var event_name: ConstCStringPointer = {}
    var event_alias: ConstCStringPointer = {}
    var event_description: ConstCStringPointer = {}
    assert_success(
        kperf_data.kpep_event_name(event, UnsafePointer(to=event_name))
    )
    print("\t- Name:", cstr_to_string(event_name))

    assert_success(
        kperf_data.kpep_event_alias(event, UnsafePointer(to=event_alias))
    )
    print("\t- Alias:", cstr_to_string(event_alias))

    assert_success(
        kperf_data.kpep_event_description(
            event, UnsafePointer(to=event_description)
        )
    )
    print("\t- Description:", cstr_to_string(event_description))


def run_kperf_data_ffi_example() raises:
    # ===--------------------------------------------------------------------===
    # Create database
    # ===--------------------------------------------------------------------===

    var db = kperf_data.KPEPDb.MutPointerType.unsafe_dangling()
    assert_success(kperf_data.kpep_db_create({}, UnsafePointer(to=db)))

    # ===--------------------------------------------------------------------===
    # Get database's names
    # ===--------------------------------------------------------------------===
    print("Database name:", cstr_to_string(db[].name))

    var db_marketing_name: ConstCStringPointer = {}
    assert_success(
        kperf_data.kpep_db_name(db, UnsafePointer(to=db_marketing_name))
    )
    assert_equal(db[].marketing_name, db_marketing_name)
    print("Database market_name:", cstr_to_string(db_marketing_name))

    # ===--------------------------------------------------------------------===
    # Get database's CPU ID
    # ===--------------------------------------------------------------------===
    print("Database CPU ID:", cstr_to_string(db[].cpu_id))

    # ===--------------------------------------------------------------------===
    # Get database's alias
    # ===--------------------------------------------------------------------===
    var db_aliases_count: c_size_t = 0
    assert_success(
        kperf_data.kpep_db_aliases_count(db, UnsafePointer(to=db_aliases_count))
    )
    print("Database alias count:", db_aliases_count)

    var db_aliases_arr = alloc(
        Layout[ConstCStringPointer](count=Int(db_aliases_count))
    ).unsafe_leak()
    var db_aliases_arr_size = UInt(
        Int(db_aliases_count) * size_of[ConstCStringPointer]()
    )
    assert_success(
        kperf_data.kpep_db_aliases(db, db_aliases_arr, db_aliases_arr_size)
    )
    print("Aliases:")
    for i in range(Int(db_aliases_count)):
        print("\t-", cstr_to_string((db_aliases_arr + i)[]))

    # ===--------------------------------------------------------------------===
    # Get database's counters count
    # ===--------------------------------------------------------------------===
    var db_counters_count: c_size_t = 0
    assert_success(
        kperf_data.kpep_db_counters_count(
            db,
            UInt8(kperf.KPC_CLASS_FIXED_MASK),
            UnsafePointer(to=db_counters_count),
        )
    )
    print("Database counters count:", db_counters_count)

    # ===--------------------------------------------------------------------===
    # Get database's event count
    # ===--------------------------------------------------------------------===
    var db_event_count: c_size_t = 0
    assert_success(
        kperf_data.kpep_db_events_count(
            db,
            UnsafePointer(to=db_event_count),
        )
    )
    print("Database event count:", db_event_count)

    # ===--------------------------------------------------------------------===
    # Get database's events-array
    # ===--------------------------------------------------------------------===
    var db_events_arr = List[
        UnsafePointer[kperf_data.KPEPEvent, MutUntrackedOrigin]
    ](unsafe_uninit_length=Int(db_event_count))
    assert_success(
        kperf_data.kpep_db_events(
            db,
            db_events_arr.unsafe_ptr(),
            db_event_count * UInt(size_of[db_events_arr._UnsafePointerType]()),
        )
    )

    # ===--------------------------------------------------------------------===
    # Get event's names, alias and description by index
    # ===--------------------------------------------------------------------===
    var event_idx = 1
    for event_idx in range(db_event_count):
        print(t"Get event info by index: {event_idx}")
        print_event_info(db_events_arr[event_idx])

    # ===--------------------------------------------------------------------===
    # Get event's names and alias
    # ===--------------------------------------------------------------------===
    var event_name = "FIXED_CYCLES"
    var event: OptionalUnsafePointer[
        kperf_data.KPEPEvent, MutUntrackedOrigin
    ] = {}
    print(t"Get event info by name: '{event_name}'")
    assert_success(
        kperf_data.kpep_db_event(
            db,
            event_name.as_c_string_slice().unsafe_ptr(),
            UnsafePointer(to=event),
        )
    )
    print_event_info(event.value())


def main() raises:
    try:
        run_kperf_data_ffi_example()
    except e:
        print(t"error: {e}")
        print("possible fix: run with sudo")
