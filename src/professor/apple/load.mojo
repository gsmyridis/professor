from std.collections import InlineArray
from std.ffi import OwnedDLHandle, c_int, c_size_t
from std.memory import UnsafePointer
from std.sys import size_of

from .ffi.kperf import (
    KPC_CLASS_CONFIGURABLE_MASK,
    KPC_MAX_COUNTERS,
    KPCConfig,
)
from .ffi.kperf_data import (
    KPEPConfig,
    KPEPConfigFreeFn,
    KPEPDb,
    KPEPDbFreeFn,
    KPEPEvent,
    kpep_config_error_desc,
    kpep_db_event,
)

comptime EVENT_NAME_MAX = 8
comptime PROFILE_EVENT_COUNT = 5


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


def _get_event(db: KPEPDb.Pointer, alias_index: Int) -> KPEPEvent.Pointer:
    for candidate_index in range(EVENT_NAME_MAX):
        var name = _event_name(alias_index, candidate_index)
        if name.byte_length() == 0:
            break
        var ev: KPEPEvent.Pointer = {}
        if (
            kpep_db_event(
                db, name.as_c_string_slice().unsafe_ptr(), UnsafePointer(to=ev)
            )
            == 0
        ):
            return ev
    return {}
