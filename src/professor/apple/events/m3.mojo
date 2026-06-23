"""Hardware performance counter event metadata for Apple Silicon.

Ported from the `darwin-kperf` crate (events/src/m3.rs), which is
auto-generated from the PMC database plists in `/usr/share/kpep/`.
Dual-licensed MIT / Apache-2.0: https://github.com/hashintel/hash/tree/main/libs/darwin-kperf

Do not edit by hand; regenerate via `scripts/port_kperf_events.py`.
"""


@fieldwise_init
struct M3Event(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """Hardware performance counter events available on M3."""

    var _tag: UInt16

    comptime AtomicOrExclusiveFail = Self(0)
    comptime AtomicOrExclusiveSucc = Self(1)
    comptime BranchCallIndirMispredNonspec = Self(2)
    comptime BranchCondMispredNonspec = Self(3)
    comptime BranchIndirMispredNonspec = Self(4)
    comptime BranchMispredNonspec = Self(5)
    comptime BranchRetIndirMispredNonspec = Self(6)
    comptime CoreActiveCycle = Self(7)
    comptime FetchRestart = Self(8)
    comptime FixedCycles = Self(9)
    comptime FixedInstructions = Self(10)
    comptime FlushRestartOtherNonspec = Self(11)
    comptime InstAll = Self(12)
    comptime InstBarrier = Self(13)
    comptime InstBranch = Self(14)
    comptime InstBranchCall = Self(15)
    comptime InstBranchIndir = Self(16)
    comptime InstBranchRet = Self(17)
    comptime InstBranchTaken = Self(18)
    comptime InstIntAlu = Self(19)
    comptime InstIntLd = Self(20)
    comptime InstIntSt = Self(21)
    comptime InstLdst = Self(22)
    comptime InstSimdAlu = Self(23)
    comptime InstSimdAluVec = Self(24)
    comptime InstSimdLd = Self(25)
    comptime InstSimdSt = Self(26)
    comptime InterruptPending = Self(27)
    comptime L1DCacheMissLd = Self(28)
    comptime L1DCacheMissLdNonspec = Self(29)
    comptime L1DCacheMissSt = Self(30)
    comptime L1DCacheMissStNonspec = Self(31)
    comptime L1DCacheWriteback = Self(32)
    comptime L1DTlbAccess = Self(33)
    comptime L1DTlbFill = Self(34)
    comptime L1DTlbMiss = Self(35)
    comptime L1DTlbMissNonspec = Self(36)
    comptime L1ICacheMissDemand = Self(37)
    comptime L1ITlbFill = Self(38)
    comptime L1ITlbMissDemand = Self(39)
    comptime L2TlbMissData = Self(40)
    comptime L2TlbMissInstruction = Self(41)
    comptime LdNtUop = Self(42)
    comptime LdUnitUop = Self(43)
    comptime LdstUnitOldL1DCacheMiss = Self(44)
    comptime LdstUnitWaitingOldL1DCacheMiss = Self(45)
    comptime LdstX64Uop = Self(46)
    comptime LdstXpgUop = Self(47)
    comptime MapDispatchBubble = Self(48)
    comptime MapDispatchBubbleIc = Self(49)
    comptime MapDispatchBubbleItlb = Self(50)
    comptime MapIntUop = Self(51)
    comptime MapLdstUop = Self(52)
    comptime MapRewind = Self(53)
    comptime MapSimdUop = Self(54)
    comptime MapStall = Self(55)
    comptime MapStallDispatch = Self(56)
    comptime MapUop = Self(57)
    comptime MmuTableWalkData = Self(58)
    comptime MmuTableWalkInstruction = Self(59)
    comptime RetireUop = Self(60)
    comptime ScheduleEmpty = Self(61)
    comptime ScheduleUop = Self(62)
    comptime StMemOrderViolLdNonspec = Self(63)
    comptime StNtUop = Self(64)
    comptime StUnitUop = Self(65)

    comptime _NAMES: InlineArray[StaticString, 66] = [
        "ATOMIC_OR_EXCLUSIVE_FAIL",
        "ATOMIC_OR_EXCLUSIVE_SUCC",
        "BRANCH_CALL_INDIR_MISPRED_NONSPEC",
        "BRANCH_COND_MISPRED_NONSPEC",
        "BRANCH_INDIR_MISPRED_NONSPEC",
        "BRANCH_MISPRED_NONSPEC",
        "BRANCH_RET_INDIR_MISPRED_NONSPEC",
        "CORE_ACTIVE_CYCLE",
        "FETCH_RESTART",
        "FIXED_CYCLES",
        "FIXED_INSTRUCTIONS",
        "FLUSH_RESTART_OTHER_NONSPEC",
        "INST_ALL",
        "INST_BARRIER",
        "INST_BRANCH",
        "INST_BRANCH_CALL",
        "INST_BRANCH_INDIR",
        "INST_BRANCH_RET",
        "INST_BRANCH_TAKEN",
        "INST_INT_ALU",
        "INST_INT_LD",
        "INST_INT_ST",
        "INST_LDST",
        "INST_SIMD_ALU",
        "INST_SIMD_ALU_VEC",
        "INST_SIMD_LD",
        "INST_SIMD_ST",
        "INTERRUPT_PENDING",
        "L1D_CACHE_MISS_LD",
        "L1D_CACHE_MISS_LD_NONSPEC",
        "L1D_CACHE_MISS_ST",
        "L1D_CACHE_MISS_ST_NONSPEC",
        "L1D_CACHE_WRITEBACK",
        "L1D_TLB_ACCESS",
        "L1D_TLB_FILL",
        "L1D_TLB_MISS",
        "L1D_TLB_MISS_NONSPEC",
        "L1I_CACHE_MISS_DEMAND",
        "L1I_TLB_FILL",
        "L1I_TLB_MISS_DEMAND",
        "L2_TLB_MISS_DATA",
        "L2_TLB_MISS_INSTRUCTION",
        "LD_NT_UOP",
        "LD_UNIT_UOP",
        "LDST_UNIT_OLD_L1D_CACHE_MISS",
        "LDST_UNIT_WAITING_OLD_L1D_CACHE_MISS",
        "LDST_X64_UOP",
        "LDST_XPG_UOP",
        "MAP_DISPATCH_BUBBLE",
        "MAP_DISPATCH_BUBBLE_IC",
        "MAP_DISPATCH_BUBBLE_ITLB",
        "MAP_INT_UOP",
        "MAP_LDST_UOP",
        "MAP_REWIND",
        "MAP_SIMD_UOP",
        "MAP_STALL",
        "MAP_STALL_DISPATCH",
        "MAP_UOP",
        "MMU_TABLE_WALK_DATA",
        "MMU_TABLE_WALK_INSTRUCTION",
        "RETIRE_UOP",
        "SCHEDULE_EMPTY",
        "SCHEDULE_UOP_ANY",
        "ST_MEM_ORDER_VIOL_LD_NONSPEC",
        "ST_NT_UOP",
        "ST_UNIT_UOP",
    ]

    comptime _DESCRIPTIONS: InlineArray[StaticString, 66] = [
        (
            "Atomic or exclusive instruction failed due to contention (for"
            " exclusives, incorrectly undercounts for exclusives when the cache"
            " line is initially found in shared state, however counts correctly"
            " for atomics)"
        ),
        (
            "Atomic or exclusive instruction successfully completed (for"
            " exclusives, incorrectly undercounts for exclusives when the cache"
            " line is initially found in shared state, however counts correctly"
            " for atomics)"
        ),
        "Retired indirect call instructions mispredicted",
        "Retired conditional branch instructions that mispredicted",
        (
            "Retired indirect branch instructions including calls and returns"
            " that mispredicted"
        ),
        "Instruction architecturally executed, mispredicted branch",
        "Retired return instructions that mispredicted",
        "Cycles while the core was active",
        (
            "Fetch Unit internal restarts for any reason. Does not include"
            " branch mispredicts"
        ),
        "",
        "",
        (
            "Pipeline flush and restarts that were not due to branch"
            " mispredictions or memory order violations"
        ),
        "All retired instructions",
        "Retired data barrier instructions",
        "Retired branch instructions including calls and returns",
        "Retired subroutine call instructions",
        "Retired indirect branch instructions including indirect calls",
        "Retired subroutine return instructions",
        "Retired taken branch instructions",
        "Retired non-branch and non-load/store Integer Unit instructions",
        "Retired load Integer Unit instructions",
        (
            "Retired store Integer Unit instructions; does not count DC ZVA"
            " (Data Cache Zero by VA)"
        ),
        (
            "Retired load and store instructions; does not count DC ZVA (Data"
            " Cache Zero by VA)"
        ),
        "Retired non-load/store Advanced SIMD and FP Unit instructions",
        "Retired non-load/store vector Advanced SIMD  instructions",
        "Retired load Advanced SIMD and FP Unit instructions",
        "Retired store Advanced SIMD and FP Unit instructions",
        "Cycles while an interrupt was pending because it was masked",
        "Loads that missed the L1 Data Cache",
        "Retired loads that missed in the L1 Data Cache",
        "Stores that missed the L1 Data Cache",
        "Retired stores that missed in the L1 Data Cache",
        (
            "Dirty cache lines written back from the L1D Cache toward the"
            " Shared L2 Cache"
        ),
        "Load and store accesses to the L1 Data TLB",
        "Translations filled into the L1 Data TLB",
        "Load and store accesses that missed the L1 Data TLB",
        "Retired loads and stores that missed in the L1 Data TLB",
        (
            "Demand fetch misses that require a new cache line fill of the L1"
            " Instruction Cache"
        ),
        "Translations filled into the L1 Instruction TLB",
        "Demand instruction fetches that missed in the L1 Instruction TLB",
        "Loads and stores that missed in the L2 TLB",
        "Instruction fetches that missed in the L2 TLB",
        (
            "Load uops that executed with non-temporal hint; excludes SSVE/SME"
            " loads because they utilize the Store Unit"
        ),
        "Uops that flowed through the Load Unit",
        (
            "Cycles while an old load or store uop is waiting for data after an"
            " L1 Data Cache miss"
        ),
        (
            "Cycles while an old load or store uop is waiting for data after an"
            " L1 Data Cache miss, and no uop was issued by the scheduler,"
            " prioritized"
        ),
        "Load and store uops that crossed a 64B boundary",
        (
            "Load and store uops that crossed a 16KiB page boundary; an SME"
            " access is considered cross-page if any bytes are accessed in the"
            " high portion (second page), regardless if any bytes are accessed"
            " in the low portion (first page), after predication is applied. An"
            " SME operation that only touches the low portion (first page)"
            " after predication is applied is not considered cross-page."
        ),
        "Cycles while the Map Unit had no uops to process and was not stalled",
        (
            "Cycles while the Map Unit had no uops to process due to L1"
            " Instruction Cache and was not stalled"
        ),
        (
            "Cycles while the Map Unit had no uops to process due to L1"
            " Instruction TLB and was not stalled"
        ),
        "Mapped Integer Unit uops",
        (
            "Mapped Load and Store Unit uops, including GPR to vector register"
            " converts; includes all instructions sent to the SME engine"
            " because they are processed through the Store Unit"
        ),
        (
            "Cycles while the Map Unit was blocked while rewinding due to flush"
            " and restart"
        ),
        "Mapped Advanced SIMD and FP Unit uops",
        "Cycles while the Map Unit was stalled for any reason",
        (
            "Cycles while the Map Unit was stalled because of Dispatch back"
            " pressure"
        ),
        "Mapped uops",
        "Table walk memory requests on behalf of data accesses",
        "Table walk memory requests on behalf of instruction fetches",
        "All retired uops",
        "Cycles while the uop scheduler is empty",
        (
            "Cycles while the uop scheduler issued at least 1 uop to any"
            " execution unit"
        ),
        (
            "Retired core store uops that triggered memory order violations"
            " with core load uops"
        ),
        (
            "Store uops that executed with non-temporal hint; includes SSVE/SME"
            " loads because they utilize the Store Unit"
        ),
        "Uops that flowed through the Store Unit",
    ]

    comptime _COUNTERS_MASK: InlineArray[Optional[UInt32], 66] = [
        None,
        None,
        UInt32(224),
        UInt32(224),
        UInt32(224),
        UInt32(224),
        UInt32(224),
        None,
        None,
        UInt32(1),
        UInt32(2),
        None,
        UInt32(128),
        UInt32(224),
        UInt32(224),
        UInt32(224),
        UInt32(224),
        UInt32(224),
        UInt32(224),
        UInt32(128),
        UInt32(224),
        UInt32(128),
        UInt32(128),
        UInt32(128),
        UInt32(128),
        UInt32(224),
        UInt32(224),
        None,
        None,
        UInt32(224),
        None,
        UInt32(224),
        None,
        None,
        None,
        None,
        UInt32(224),
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        UInt32(128),
        None,
        None,
        UInt32(224),
        None,
        None,
    ]

    comptime _NUMBER: InlineArray[Optional[UInt16], 66] = [
        UInt16(1460),
        UInt16(1459),
        UInt16(202),
        UInt16(197),
        UInt16(198),
        UInt16(203),
        UInt16(200),
        UInt16(2),
        UInt16(478),
        None,
        None,
        UInt16(132),
        UInt16(140),
        UInt16(156),
        UInt16(141),
        UInt16(142),
        UInt16(147),
        UInt16(143),
        UInt16(144),
        UInt16(151),
        UInt16(149),
        UInt16(150),
        UInt16(155),
        UInt16(154),
        UInt16(159),
        UInt16(152),
        UInt16(153),
        UInt16(620),
        UInt16(1443),
        UInt16(191),
        UInt16(1442),
        UInt16(192),
        UInt16(1448),
        UInt16(1440),
        UInt16(1029),
        UInt16(1441),
        UInt16(193),
        UInt16(475),
        UInt16(1028),
        UInt16(468),
        UInt16(1035),
        UInt16(1034),
        UInt16(1510),
        UInt16(1446),
        UInt16(656),
        UInt16(657),
        UInt16(1457),
        UInt16(1458),
        UInt16(470),
        UInt16(386),
        UInt16(387),
        UInt16(636),
        UInt16(637),
        UInt16(629),
        UInt16(638),
        UInt16(630),
        UInt16(624),
        UInt16(617),
        UInt16(1032),
        UInt16(1031),
        UInt16(1),
        UInt16(849),
        UInt16(643),
        UInt16(196),
        UInt16(1509),
        UInt16(1447),
    ]

    comptime _FIXED_COUNTER: InlineArray[Optional[UInt8], 66] = [
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        UInt8(0),
        UInt8(1),
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
    ]

    comptime _FALLBACK: InlineArray[Optional[StaticString], 66] = [
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        StaticString("INST_ALL"),
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
    ]

    comptime _ALIAS: InlineArray[Optional[StaticString], 66] = [
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        StaticString("Cycles"),
        StaticString("Instructions"),
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
    ]

    def __eq__(self, other: Self) -> Bool:
        return self._tag == other._tag

    def __ne__(self, other: Self) -> Bool:
        return self._tag != other._tag

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.name())

    def name(self) -> StaticString:
        """The kpep event name, e.g. `"INST_ALL"`."""
        return Self._NAMES[Int(self._tag)]

    def description(self) -> StaticString:
        return Self._DESCRIPTIONS[Int(self._tag)]

    def counters_mask(self) -> Optional[UInt32]:
        return Self._COUNTERS_MASK[Int(self._tag)]

    def number(self) -> Optional[UInt16]:
        return Self._NUMBER[Int(self._tag)]

    def fixed_counter(self) -> Optional[UInt8]:
        return Self._FIXED_COUNTER[Int(self._tag)]

    def fallback(self) -> Optional[StaticString]:
        return Self._FALLBACK[Int(self._tag)]

    def aliases(self) -> List[StaticString]:
        var result = List[StaticString]()
        var a = Self._ALIAS[Int(self._tag)]
        if a:
            result.append(a.value())
        return result^
