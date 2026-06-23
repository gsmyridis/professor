"""Runtime layout checks for `professor.apple.ffi.kperf_data`.

These tests use `kperfdata.framework` getter functions as the oracle, then
compare those results with direct reads from our Mojo struct definitions.
They do not require root privileges.
"""

from std.ffi import c_char, c_size_t
from std.testing import assert_equal, assert_true
from std.testing import TestSuite

from professor.apple.ffi.kperf_data import (
    ConstCStringPointer,
    KPEPConfig,
    KPEPDb,
    KPEPEvent,
    kpep_config_add_event,
    kpep_config_create,
    kpep_config_events_count,
    kpep_config_force_counters,
    kpep_config_free,
    kpep_config_kpc_classes,
    kpep_db_aliases_count,
    kpep_db_create,
    kpep_db_event,
    kpep_db_events_count,
    kpep_db_free,
    kpep_db_name,
    kpep_event_alias,
    kpep_event_description,
    kpep_event_name,
)


struct RawDatabase(Movable):
    var ptr: KPEPDb.Pointer

    def __init__(out self) raises:
        var ptr = KPEPDb.Pointer.unsafe_dangling()
        assert_equal(kpep_db_create({}, UnsafePointer(to=ptr)), 0)
        self.ptr = ptr

    def __del__(deinit self):
        kpep_db_free(self.ptr)

    def events(self) raises -> List[KPEPEvent.Pointer]:
        var count: c_size_t = 0
        var res = kpep_db_events_count(self.ptr, UnsafePointer(to=count))
        assert_equal(res, 0, "failed to read events count")

        assert_true(Bool(self.ptr[].event_arr), "events array is null pointer")
        var base = self.ptr[].event_arr.value()

        var events = List[KPEPEvent.Pointer](capacity=Int(count))
        for i in range(Int(count)):
            events.append(KPEPEvent.Pointer(base + i))

        return events^


struct RawConfig(Movable):
    var ptr: KPEPConfig.Pointer

    def __init__(out self, db: KPEPDb.Pointer) raises:
        var ptr: KPEPConfig.Pointer = {}
        assert_equal(kpep_config_create(db, UnsafePointer(to=ptr)), 0)
        self.ptr = ptr

    def __del__(deinit self):
        kpep_config_free(self.ptr)


def _c_str(ptr: ConstCStringPointer) -> String:
    if not ptr:
        return String()
    try:
        return String(unsafe_from_utf8_ptr=ptr[].bitcast[UInt8]())
    except:
        return String()


def _getter_name(event: KPEPEvent.Pointer) raises -> String:
    var ptr: ConstCStringPointer = {}
    assert_equal(kpep_event_name(event, UnsafePointer(to=ptr)), 0)
    return _c_str(ptr)


def _getter_alias(event: KPEPEvent.Pointer) raises -> String:
    var ptr: ConstCStringPointer = {}
    assert_equal(kpep_event_alias(event, UnsafePointer(to=ptr)), 0)
    return _c_str(ptr)


def _getter_description(event: KPEPEvent.Pointer) raises -> String:
    var ptr: ConstCStringPointer = {}
    assert_equal(kpep_event_description(event, UnsafePointer(to=ptr)), 0)
    return _c_str(ptr)


# ===---------------------------------------------------------------------------------===
# Test database fields
# ===---------------------------------------------------------------------------------===


def test_database_layout_events_counts() raises:
    var db = RawDatabase()

    var event_count: c_size_t = 0
    var res = kpep_db_events_count(db.ptr, UnsafePointer(to=event_count))
    assert_equal(res, 0, "failed to read events count")
    assert_equal(
        Int(db.ptr[].event_count),
        Int(event_count),
        "events counts do not match",
    )


def test_database_layout_alias_counts() raises:
    var db = RawDatabase()

    var alias_count: c_size_t = 0
    var res = kpep_db_aliases_count(db.ptr, UnsafePointer(to=alias_count))
    assert_equal(res, 0, "failed to read alias counts")
    assert_equal(
        Int(db.ptr[].alias_count), Int(alias_count), "alias counts do not match"
    )


def test_database_layout_marketing_names() raises:
    var db = RawDatabase()

    var marketing_name: ConstCStringPointer = {}
    var res = kpep_db_name(db.ptr, UnsafePointer(to=marketing_name))
    assert_equal(res, 0, "failed to read database marketing name")
    assert_equal(
        _c_str(db.ptr[].marketing_name),
        _c_str(marketing_name),
        "database marketing names do not match",
    )


# ===---------------------------------------------------------------------------------===
# Test event fields
# ===---------------------------------------------------------------------------------===


def test_event_layout_name() raises:
    var db = RawDatabase()
    var events = db.events()
    assert_true(len(events) > 0)

    for event in events:
        assert_true(Bool(event), "event pointer is null")
        assert_equal(
            _c_str(event.value()[].name),
            _getter_name(event),
            "event names do not match",
        )


def test_event_layout_alias() raises:
    var db = RawDatabase()
    var events = db.events()
    assert_true(len(events) > 0)

    for event in events:
        assert_true(Bool(event), "event pointer is null")
        assert_equal(
            _c_str(event.value()[].alias_name),
            _getter_alias(event),
            "event aliases do not match",
        )


def test_event_layout_description() raises:
    var db = RawDatabase()
    var events = db.events()
    assert_true(len(events) > 0)

    for event in events:
        assert_true(Bool(event), "event pointer is null")
        assert_equal(
            _c_str(event.value()[].description),
            _getter_description(event),
            "event descriptions do not match",
        )


def test_known_event_lookup_fields_match_framework_getters() raises:
    var db = RawDatabase()

    var inst_name = String("INST_ALL")
    var inst: KPEPEvent.Pointer = {}
    assert_equal(
        kpep_db_event(
            db.ptr,
            inst_name.unsafe_ptr().bitcast[c_char](),
            UnsafePointer(to=inst),
        ),
        0,
    )
    assert_equal(_c_str(inst.value()[].name), _getter_name(inst))
    assert_equal(_c_str(inst.value()[].alias_name), _getter_alias(inst))


def test_config_fields_match_framework_getters_after_add_event() raises:
    var db = RawDatabase()
    var cfg = RawConfig(db.ptr)

    assert_equal(kpep_config_force_counters(cfg.ptr), 0)

    var name = String("INST_ALL")
    var event: KPEPEvent.Pointer = {}
    assert_equal(
        kpep_db_event(
            db.ptr,
            name.unsafe_ptr().bitcast[c_char](),
            UnsafePointer(to=event),
        ),
        0,
    )
    assert_true(Bool(event))

    var conflict_bits: UInt32 = 0
    assert_equal(
        kpep_config_add_event(
            cfg.ptr,
            UnsafePointer(to=event),
            0,
            UnsafePointer(to=conflict_bits),
        ),
        0,
    )

    var event_count: c_size_t = 0
    assert_equal(
        kpep_config_events_count(cfg.ptr, UnsafePointer(to=event_count)), 0
    )
    assert_equal(Int(cfg.ptr.value()[].event_count), Int(event_count))

    var classes: UInt32 = 0
    assert_equal(kpep_config_kpc_classes(cfg.ptr, UnsafePointer(to=classes)), 0)
    assert_equal(cfg.ptr.value()[].classes, classes)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
