from std.collections import InlineArray
from std.ffi import OwnedDLHandle, c_int, c_size_t
from std.memory import UnsafePointer
from std.sys import size_of

from .kperf import (
    KPC_CLASS_CONFIGURABLE_MASK,
    KPC_MAX_COUNTERS,
    KPCConfig,
    _KPerfSymbols,
)
from .kperf_data import (
    KPEPConfig,
    KPEPConfigFreeFn,
    KPEPDb,
    KPEPDbFreeFn,
    KPEPEvent,
    _KPEPSymbols,
    kpep_config_error_desc,
)

comptime EVENT_NAME_MAX = 8
comptime PROFILE_EVENT_COUNT = 5


@fieldwise_init
struct PerformanceCounters(Copyable, ImplicitlyCopyable, Movable):
    var cycles: Float64
    var branches: Float64
    var missed_branches: Float64
    var instructions: Float64
    var cache_misses: Float64

    @staticmethod
    def zero() -> Self:
        return Self(0.0, 0.0, 0.0, 0.0, 0.0)

    def __sub__(self, other: Self) -> Self:
        return Self(
            self.cycles - other.cycles,
            self.branches - other.branches,
            self.missed_branches - other.missed_branches,
            self.instructions - other.instructions,
            self.cache_misses - other.cache_misses,
        )


struct _KPerfHandle(Movable):
    var handle: OwnedDLHandle
    var symbols: _KPerfSymbols

    def __init__(out self) raises:
        self.handle = OwnedDLHandle(
            "/System/Library/PrivateFrameworks/kperf.framework/kperf"
        )
        self.symbols = _KPerfSymbols(self.handle)


struct _KPerfDataHandle(Movable):
    var handle: OwnedDLHandle
    var symbols: _KPEPSymbols

    def __init__(out self) raises:
        self.handle = OwnedDLHandle(
            "/System/Library/PrivateFrameworks/kperfdata.framework/kperfdata"
        )
        self.symbols = _KPEPSymbols(self.handle)


struct _KpepDBHandle(Movable):
    var ptr: KPEPDb.Pointer
    var free_fn: KPEPDbFreeFn

    def __init__(out self, ptr: KPEPDb.Pointer, free_fn: KPEPDbFreeFn):
        self.ptr = ptr
        self.free_fn = free_fn

    def __del__(deinit self):
        if self.ptr:
            self.free_fn(self.ptr)


struct _KpepConfigHandle(Movable):
    var ptr: KPEPConfig.Pointer
    var free_fn: KPEPConfigFreeFn

    def __init__(out self, ptr: KPEPConfig.Pointer, free_fn: KPEPConfigFreeFn):
        self.ptr = ptr
        self.free_fn = free_fn

    def __del__(deinit self):
        if self.ptr:
            self.free_fn(self.ptr)


def _event_name(alias_index: Int, candidate_index: Int) -> String:
    if alias_index == 0:
        if candidate_index == 0:
            return "FIXED_CYCLES"
        if candidate_index == 1:
            return "CPU_CLK_UNHALTED.THREAD"
        if candidate_index == 2:
            return "CPU_CLK_UNHALTED.CORE"
    if alias_index == 1:
        if candidate_index == 0:
            return "FIXED_INSTRUCTIONS"
        if candidate_index == 1:
            return "INST_RETIRED.ANY"
    if alias_index == 2:
        if candidate_index == 0:
            return "INST_BRANCH"
        if candidate_index == 1:
            return "BR_INST_RETIRED.ALL_BRANCHES"
        if candidate_index == 2:
            return "INST_RETIRED.ANY"
    if alias_index == 3:
        if candidate_index == 0:
            return "BRANCH_MISPRED_NONSPEC"
        if candidate_index == 1:
            return "BRANCH_MISPREDICT"
        if candidate_index == 2:
            return "BR_MISP_RETIRED.ALL_BRANCHES"
        if candidate_index == 3:
            return "BR_INST_RETIRED.MISPRED"
    if alias_index == 4:
        if candidate_index == 0:
            return "L2_CACHE_MISS_DATA"
        if candidate_index == 1:
            return "L1D_CACHE_MISS_LD"
        if candidate_index == 2:
            return "L1D_CACHE_MISS_LD_NONSPEC"
        if candidate_index == 3:
            return "LONGEST_LAT_CACHE.MISS"
        if candidate_index == 4:
            return "MEM_LOAD_RETIRED.L3_MISS"
    return ""


def _event_alias(alias_index: Int) -> String:
    if alias_index == 0:
        return "cycles"
    if alias_index == 1:
        return "instructions"
    if alias_index == 2:
        return "branches"
    if alias_index == 3:
        return "branch-misses"
    if alias_index == 4:
        return "cache-misses"
    return "unknown"


def _get_event(
    db: KPEPDb.Pointer, alias_index: Int, symbols: _KPEPSymbols
) -> KPEPEvent.Pointer:
    for candidate_index in range(EVENT_NAME_MAX):
        var name = _event_name(alias_index, candidate_index)
        if name.byte_length() == 0:
            break
        var ev: KPEPEvent.Pointer = {}
        if (
            symbols.kpep_db_event(
                db, name.as_c_string_slice().unsafe_ptr(), UnsafePointer(to=ev)
            )
            == 0
        ):
            return ev
    return {}


# struct AppleEvents(Movable):
#     var regs: InlineArray[KPCConfig, KPC_MAX_COUNTERS]
#     var counter_map: InlineArray[c_size_t, KPC_MAX_COUNTERS]
#     var counters_0: InlineArray[UInt64, KPC_MAX_COUNTERS]
#     var counters_1: InlineArray[UInt64, KPC_MAX_COUNTERS]
#     var init: Bool
#     var worked: Bool

#     def __init__(out self):
#         self.regs = InlineArray[KPCConfig, KPC_MAX_COUNTERS](fill=0)
#         self.counter_map = InlineArray[c_size_t, KPC_MAX_COUNTERS](fill=0)
#         self.counters_0 = InlineArray[UInt64, KPC_MAX_COUNTERS](fill=0)
#         self.counters_1 = InlineArray[UInt64, KPC_MAX_COUNTERS](fill=0)
#         self.init = False
#         self.worked = False

#     def setup(mut self, libs: LibraryHandle) -> Bool:
#         if self.init:
#             return self.worked
#         self.init = True

#         var force_ctrs: c_int = 0
#         if libs.kperf.kpc_force_all_ctrs_get(UnsafePointer(to=force_ctrs)) != 0:
#             self.worked = False
#             return False

#         var db_ptr: KPEPDb.Pointer = {}
#         var ret = libs.kpep.kpep_db_create({}, UnsafePointer(to=db_ptr))
#         if ret != 0:
#             print(t"Error: cannot load pmc database: {ret}.")
#             self.worked = False
#             return False

#         var db = _KpepDBHandle(db_ptr, libs.kpep.kpep_db_free)

#         var cfg_ptr: KPEPConfig.Pointer = {}
#         ret = libs.kpep.kpep_config_create(db.ptr, UnsafePointer(to=cfg_ptr))
#         if ret != 0:
#             print(
#                 t"Failed to create kpep config:"
#                 t" {ret} ({kpep_config_error_desc(Int(ret))})."
#             )
#             self.worked = False
#             return False

#         var cfg = _KpepConfigHandle(cfg_ptr, libs.kpep.kpep_config_free)

#         ret = libs.kpep.kpep_config_force_counters(cfg.ptr)
#         if ret != 0:
#             print(
#                 t"Failed to force counters:"
#                 t" {ret} ({kpep_config_error_desc(Int(ret))})."
#             )
#             self.worked = False
#             return False

#         var ev_arr = InlineArray[KPEPEvent.Pointer, PROFILE_EVENT_COUNT](fill={})
#         for i in range(PROFILE_EVENT_COUNT):
#             ev_arr[i] = _get_event(db.ptr, i, libs.kpep)
#             if not ev_arr[i]:
#                 print(t"Cannot find event: {_event_alias(i)}.")
#                 self.worked = False
#                 return False

#         for i in range(PROFILE_EVENT_COUNT):
#             var ev = ev_arr[i]
#             ret = libs.kpep.kpep_config_add_event(
#                 cfg.ptr, UnsafePointer(to=ev), 0, {}
#             )
#             if ret != 0:
#                 print(
#                     t"Failed to add event:"
#                     t" {ret} ({kpep_config_error_desc(Int(ret))})."
#                 )
#                 self.worked = False
#                 return False

#         var classes: UInt32 = 0
#         var reg_count: c_size_t = 0
#         ret = libs.kpep.kpep_config_kpc_classes(
#             cfg.ptr, UnsafePointer(to=classes)
#         )
#         if ret != 0:
#             print(
#                 t"Failed get kpc classes:"
#                 t" {ret} ({kpep_config_error_desc(Int(ret))})."
#             )
#             self.worked = False
#             return False

#         ret = libs.kpep.kpep_config_kpc_count(
#             cfg.ptr, UnsafePointer(to=reg_count)
#         )
#         if ret != 0:
#             print(
#                 t"Failed get kpc count:"
#                 t" {ret} ({kpep_config_error_desc(Int(ret))})."
#             )
#             self.worked = False
#             return False

#         ret = libs.kpep.kpep_config_kpc_map(
#             cfg.ptr,
#             self.counter_map.unsafe_ptr(),
#             c_size_t(KPC_MAX_COUNTERS * size_of[c_size_t]()),
#         )
#         if ret != 0:
#             print(
#                 t"Failed get kpc map:"
#                 t" {ret} ({kpep_config_error_desc(Int(ret))})."
#             )
#             self.worked = False
#             return False

#         ret = libs.kpep.kpep_config_kpc(
#             cfg.ptr,
#             self.regs.unsafe_ptr(),
#             c_size_t(KPC_MAX_COUNTERS * size_of[KPCConfig]()),
#         )
#         if ret != 0:
#             print(
#                 t"Failed get kpc registers:"
#                 t" {ret} ({kpep_config_error_desc(Int(ret))})."
#             )
#             self.worked = False
#             return False

#         ret = libs.kperf.kpc_force_all_ctrs_set(1)
#         if ret != 0:
#             print(t"Failed force all ctrs: {ret}.")
#             self.worked = False
#             return False

#         if (classes & KPC_CLASS_CONFIGURABLE_MASK) != 0 and reg_count != 0:
#             ret = libs.kperf.kpc_set_config(classes, self.regs.unsafe_ptr())
#             if ret != 0:
#                 print(t"Failed set kpc config: {ret}.")
#                 self.worked = False
#                 return False

#         ret = libs.kperf.kpc_set_counting(classes)
#         if ret != 0:
#             print(t"Failed set counting: {ret}.")
#             self.worked = False
#             return False

#         ret = libs.kperf.kpc_set_thread_counting(classes)
#         if ret != 0:
#             print(t"Failed set thread counting: {ret}.")
#             self.worked = False
#             return False

#         self.worked = True
#         return True

#     def get(mut self, libs: LibraryHandle) -> PerformanceCounters:
#         var r = PerformanceCounters.zero()
#         var ret = libs.kperf.kpc_get_thread_counters(
#             0, UInt32(KPC_MAX_COUNTERS), self.counters_0.unsafe_ptr()
#         )
#         if ret != 0:
#             print(t"Failed get thread counters before: {ret}.")
#             return PerformanceCounters(1.0, 1.0, 1.0, 1.0, 1.0)

#         r.cycles = Float64(self.counters_0[Int(self.counter_map[0])])
#         r.branches = Float64(self.counters_0[Int(self.counter_map[2])])
#         r.missed_branches = Float64(self.counters_0[Int(self.counter_map[3])])
#         r.instructions = Float64(self.counters_0[Int(self.counter_map[1])])
#         r.cache_misses = Float64(self.counters_0[Int(self.counter_map[4])])
#         return r
