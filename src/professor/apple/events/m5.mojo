"""Hardware performance counter event metadata for Apple Silicon.

Ported from the `darwin-kperf` crate (events/src/m5.rs), which is
auto-generated from the PMC database plists in `/usr/share/kpep/`.
Dual-licensed MIT / Apache-2.0: https://github.com/hashintel/hash/tree/main/libs/darwin-kperf

Do not edit by hand; regenerate via `scripts/port_kperf_events.py`.
"""


@fieldwise_init
struct M5Event(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """Hardware performance counter events available on M5."""

    var _tag: UInt16

    comptime ArmBrMisPred = Self(0)
    comptime ArmBrPred = Self(1)
    comptime ArmL1DCache = Self(2)
    comptime ArmL1DCacheLmissRd = Self(3)
    comptime ArmL1DCacheRd = Self(4)
    comptime ArmL1DCacheRefill = Self(5)
    comptime ArmStall = Self(6)
    comptime ArmStallBackend = Self(7)
    comptime ArmStallFrontend = Self(8)
    comptime ArmStallSlot = Self(9)
    comptime ArmStallSlotBackend = Self(10)
    comptime ArmStallSlotFrontend = Self(11)
    comptime AtomicOrExclusiveFail = Self(12)
    comptime AtomicOrExclusiveSucc = Self(13)
    comptime BranchCallIndirMispredNonspec = Self(14)
    comptime BranchCondMispredNonspec = Self(15)
    comptime BranchIndirMispredNonspec = Self(16)
    comptime BranchMispredNonspec = Self(17)
    comptime BranchRetIndirMispredNonspec = Self(18)
    comptime CoreActiveCycle = Self(19)
    comptime FetchRestart = Self(20)
    comptime FixedCycles = Self(21)
    comptime FixedInstructions = Self(22)
    comptime FlushRestartOtherNonspec = Self(23)
    comptime InstAll = Self(24)
    comptime InstBarrier = Self(25)
    comptime InstBranch = Self(26)
    comptime InstBranchCall = Self(27)
    comptime InstBranchCond = Self(28)
    comptime InstBranchIndir = Self(29)
    comptime InstBranchRet = Self(30)
    comptime InstBranchTaken = Self(31)
    comptime InstIntAlu = Self(32)
    comptime InstIntLd = Self(33)
    comptime InstIntSt = Self(34)
    comptime InstLdst = Self(35)
    comptime InstSimdAlu = Self(36)
    comptime InstSimdAluVec = Self(37)
    comptime InstSimdLd = Self(38)
    comptime InstSimdSt = Self(39)
    comptime InstSmeEngineAlu = Self(40)
    comptime InstSmeEngineLd = Self(41)
    comptime InstSmeEnginePackingFused = Self(42)
    comptime InstSmeEngineScalarfp = Self(43)
    comptime InstSmeEngineSt = Self(44)
    comptime InterruptPending = Self(45)
    comptime L1DCacheMissLd = Self(46)
    comptime L1DCacheMissLdNonspec = Self(47)
    comptime L1DCacheMissSt = Self(48)
    comptime L1DCacheMissStNonspec = Self(49)
    comptime L1DCacheWriteback = Self(50)
    comptime L1DTlbAccess = Self(51)
    comptime L1DTlbFill = Self(52)
    comptime L1DTlbMiss = Self(53)
    comptime L1DTlbMissNonspec = Self(54)
    comptime L1ICacheMissDemand = Self(55)
    comptime L1ITlbFill = Self(56)
    comptime L1ITlbMissDemand = Self(57)
    comptime L2TlbMissData = Self(58)
    comptime L2TlbMissInstruction = Self(59)
    comptime LdBlockedBySmeLdst = Self(60)
    comptime LdNtUop = Self(61)
    comptime LdSmeNormalUop = Self(62)
    comptime LdSmeNtUop = Self(63)
    comptime LdUnitUop = Self(64)
    comptime LdUnitWaitingYoungL1DCacheMiss = Self(65)
    comptime LdstSmePredInactive = Self(66)
    comptime LdstSmeXpgUop = Self(67)
    comptime LdstUnitOldL1DCacheMiss = Self(68)
    comptime LdstUnitWaitingOldL1DCacheMiss = Self(69)
    comptime LdstUnitWaitingSmeEngineInstQueueFull = Self(70)
    comptime LdstUnitWaitingSmeEngineMemData = Self(71)
    comptime LdstX64Uop = Self(72)
    comptime LdstXpgUop = Self(73)
    comptime MapDispatchBubble = Self(74)
    comptime MapDispatchBubbleIc = Self(75)
    comptime MapDispatchBubbleItlb = Self(76)
    comptime MapDispatchBubbleSlot = Self(77)
    comptime MapIntSmeUop = Self(78)
    comptime MapIntUop = Self(79)
    comptime MapLdstUop = Self(80)
    comptime MapRecovery = Self(81)
    comptime MapRewind = Self(82)
    comptime MapSimdUop = Self(83)
    comptime MapStall = Self(84)
    comptime MapStallDispatch = Self(85)
    comptime MapStallNonrecovery = Self(86)
    comptime MapUop = Self(87)
    comptime MmuTableWalkData = Self(88)
    comptime MmuTableWalkInstruction = Self(89)
    comptime RetireUop = Self(90)
    comptime ScheduleEmpty = Self(91)
    comptime ScheduleUop = Self(92)
    comptime ScheduleWaitingSmeEngineRegData = Self(93)
    comptime SmeEngineSmEnable = Self(94)
    comptime SmeEngineSmZaEnable = Self(95)
    comptime SmeEngineZaEnabledSmDisabled = Self(96)
    comptime StBarrierBlockedBySmeLdst = Self(97)
    comptime StMemOrderViolLdNonspec = Self(98)
    comptime StNtUop = Self(99)
    comptime StSmeNormalUop = Self(100)
    comptime StSmeNtUop = Self(101)
    comptime StUnitUop = Self(102)

    comptime _NAMES: InlineArray[StaticString, 103] = [
        "ARM_BR_MIS_PRED",
        "ARM_BR_PRED",
        "ARM_L1D_CACHE",
        "ARM_L1D_CACHE_LMISS_RD",
        "ARM_L1D_CACHE_RD",
        "ARM_L1D_CACHE_REFILL",
        "ARM_STALL",
        "ARM_STALL_BACKEND",
        "ARM_STALL_FRONTEND",
        "ARM_STALL_SLOT",
        "ARM_STALL_SLOT_BACKEND",
        "ARM_STALL_SLOT_FRONTEND",
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
        "INST_BRANCH_COND",
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
        "INST_SME_ENGINE_ALU",
        "INST_SME_ENGINE_LD",
        "INST_SME_ENGINE_PACKING_FUSED",
        "INST_SME_ENGINE_SCALARFP",
        "INST_SME_ENGINE_ST",
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
        "LD_BLOCKED_BY_SME_LDST",
        "LD_NT_UOP",
        "LD_SME_NORMAL_UOP",
        "LD_SME_NT_UOP",
        "LD_UNIT_UOP",
        "LD_UNIT_WAITING_YOUNG_L1D_CACHE_MISS",
        "LDST_SME_PRED_INACTIVE",
        "LDST_SME_XPG_UOP",
        "LDST_UNIT_OLD_L1D_CACHE_MISS",
        "LDST_UNIT_WAITING_OLD_L1D_CACHE_MISS",
        "LDST_UNIT_WAITING_SME_ENGINE_INST_QUEUE_FULL",
        "LDST_UNIT_WAITING_SME_ENGINE_MEM_DATA",
        "LDST_X64_UOP",
        "LDST_XPG_UOP",
        "MAP_DISPATCH_BUBBLE",
        "MAP_DISPATCH_BUBBLE_IC",
        "MAP_DISPATCH_BUBBLE_ITLB",
        "MAP_DISPATCH_BUBBLE_SLOT",
        "MAP_INT_SME_UOP",
        "MAP_INT_UOP",
        "MAP_LDST_UOP",
        "MAP_RECOVERY",
        "MAP_REWIND",
        "MAP_SIMD_UOP",
        "MAP_STALL",
        "MAP_STALL_DISPATCH",
        "MAP_STALL_NONRECOVERY",
        "MAP_UOP",
        "MMU_TABLE_WALK_DATA",
        "MMU_TABLE_WALK_INSTRUCTION",
        "RETIRE_UOP",
        "SCHEDULE_EMPTY",
        "SCHEDULE_UOP_ANY",
        "SCHEDULE_WAITING_SME_ENGINE_REG_DATA",
        "SME_ENGINE_SM_ENABLE",
        "SME_ENGINE_SM_ZA_ENABLE",
        "SME_ENGINE_ZA_ENABLED_SM_DISABLED",
        "ST_BARRIER_BLOCKED_BY_SME_LDST",
        "ST_MEM_ORDER_VIOL_LD_NONSPEC",
        "ST_NT_UOP",
        "ST_SME_NORMAL_UOP",
        "ST_SME_NT_UOP",
        "ST_UNIT_UOP",
    ]

    comptime _DESCRIPTIONS: InlineArray[StaticString, 103] = [
        "Mispredicted or not predicted branch Speculatively executed",
        "Predictable branch Speculatively executed",
        "Level 1 data cache access",
        "Level 1 data cache long-latency read miss",
        "Attributable Level 1 data cache access, read",
        "Level 1 data cache refill",
        "No operation sent for execution",
        "No operation issued due to the backend",
        "No operation issued due to the frontend",
        "No operation sent for execution on a slot",
        "No operation sent for execution on a Slot due to the backend",
        "No operation sent for execution on a Slot due to the frontend",
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
        (
            "Retired conditional branch instructions (on M3 and prior,"
            " incorrectly only counts only B.cond instructions, where on M4 and"
            " following, adds CBZ/CBNZ/TBZ/TBNZ instructions to form the"
            " complete set of conditional branch instructions)"
        ),
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
        "Retired non-load/store SME engine instructions",
        "Retired load SME engine instructions",
        (
            "Retired non-load/store SME engine instructions that were packed"
            " with another to reduce instruction bandwidth to the SME engine"
        ),
        "Retired scalar floating-point SME engine instructions",
        "Retired store SME engine instructions",
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
        "Core load uops blocked by SME accesses to same 4KiB page",
        (
            "Load uops that executed with non-temporal hint; excludes SSVE/SME"
            " loads because they utilize the Store Unit"
        ),
        "SME engine load uops with Normal memory type",
        "SME engine load uops that executed with non-temporal hint",
        "Uops that flowed through the Load Unit",
        (
            "Cycles while a younger load uop is waiting for data after an L1"
            " Data Cache miss, and no uop was issued by the scheduler with no"
            " critical miss, prioritized"
        ),
        (
            "SME engine load and store uops where all lanes are inactive due to"
            " the governing predicate; for a page-crossing load or store, the"
            " event may incorrectly count when all of the elements of the low"
            " page are predicated off, even if some of the elements on the high"
            " page are active. In Apple silicon cores, where predication is"
            " recommend primarily for data structure edge control (discarding"
            " elements 'past the end of the data structure'), this scenario"
            " should not be common."
        ),
        (
            "SME engine load and store accesses that crossed a 16KiB page"
            " boundary; an access is considered cross-page if any bytes are"
            " accessed in the high portion (second page), regardless if any"
            " bytes are accessed in the low portion (first page), after"
            " predication is applied. An SME operation that only touches the"
            " low portion (first page) after predication is applied is not"
            " considered cross-page."
        ),
        (
            "Cycles while an old load or store uop is waiting for data after an"
            " L1 Data Cache miss"
        ),
        (
            "Cycles while an old load or store uop is waiting for data after an"
            " L1 Data Cache miss, and no uop was issued by the scheduler,"
            " prioritized"
        ),
        (
            "Cycles while the instruction queue to the SME engine is full, and"
            " no uop was issued by the scheduler with no critical miss,"
            " prioritized"
        ),
        (
            "Cycles while the core is waiting for the SME engine to produce"
            " memory data, and no uop was issued by the scheduler, prioritized"
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
        "Slots where the Map Unit had no uops to process and was not stalled",
        "Mapped core Integer Unit uops for SME engine instructions",
        "Mapped Integer Unit uops",
        (
            "Mapped Load and Store Unit uops, including GPR to vector register"
            " converts; includes all instructions sent to the SME engine"
            " because they are processed through the Store Unit"
        ),
        (
            "Cycles while the Map Unit was stalled while recovering from a"
            " flush and restart"
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
        (
            "Cycles while the Map Unit was stalled for any reason other than"
            " recovery"
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
            "Cycles while the core is waiting for register, predicate, or flag"
            " data from the SME engine, and no uop was issued by the scheduler"
            " with no critical miss, prioritized"
        ),
        "Transitions into SME engine Streaming Mode (PSTATE.SM: 0 to 1)",
        (
            "Simultaneous transitions into SME engine Streaming Mode and ZA"
            " Mode (PSTATE.SM: 0 to 1 and PSTATE.ZA: 0 to 1)"
        ),
        (
            "Cycles while SME engine ZA Mode is enabled but Streaming Mode is"
            " not (PSTATE.ZA=1 and PSTATE.SM=0)"
        ),
        (
            "Core store uops blocked by SME accesses to same 4KiB page, and any"
            " barriers or store-release uops blocked by SME accesses"
        ),
        (
            "Retired core store uops that triggered memory order violations"
            " with core load uops"
        ),
        (
            "Store uops that executed with non-temporal hint; includes SSVE/SME"
            " loads because they utilize the Store Unit"
        ),
        "SME engine store uops with Normal memory type",
        "SME engine store uops that executed with non-temporal hint",
        "Uops that flowed through the Store Unit",
    ]

    comptime _COUNTERS_MASK: InlineArray[Optional[UInt32], 103] = [
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
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        None,
        None,
        UInt32(1),
        UInt32(2),
        None,
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(128),
        UInt32(252),
        UInt32(128),
        UInt32(128),
        UInt32(128),
        UInt32(128),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        UInt32(252),
        None,
        UInt32(252),
        UInt32(252),
        None,
        None,
        UInt32(252),
        None,
        UInt32(252),
        None,
        None,
        None,
        None,
        UInt32(252),
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
        UInt32(252),
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        UInt32(252),
        None,
        None,
        None,
        None,
    ]

    comptime _NUMBER: InlineArray[Optional[UInt16], 103] = [
        UInt16(16),
        UInt16(18),
        UInt16(4),
        UInt16(57),
        UInt16(64),
        UInt16(3),
        UInt16(60),
        UInt16(36),
        UInt16(35),
        UInt16(63),
        UInt16(61),
        UInt16(62),
        UInt16(1460),
        UInt16(1459),
        UInt16(2250),
        UInt16(2245),
        UInt16(2246),
        UInt16(34),
        UInt16(2248),
        UInt16(17),
        UInt16(478),
        None,
        None,
        UInt16(2180),
        UInt16(8),
        UInt16(2204),
        UInt16(33),
        UInt16(2190),
        UInt16(2196),
        UInt16(2195),
        UInt16(2191),
        UInt16(2192),
        UInt16(2199),
        UInt16(2197),
        UInt16(2198),
        UInt16(2203),
        UInt16(2202),
        UInt16(2207),
        UInt16(2200),
        UInt16(2201),
        UInt16(2211),
        UInt16(2209),
        UInt16(1321),
        UInt16(2208),
        UInt16(2210),
        UInt16(620),
        UInt16(1443),
        UInt16(2239),
        UInt16(1442),
        UInt16(2240),
        UInt16(1448),
        UInt16(1440),
        UInt16(1029),
        UInt16(1441),
        UInt16(2241),
        UInt16(16390),
        UInt16(1028),
        UInt16(468),
        UInt16(1035),
        UInt16(1034),
        UInt16(1324),
        UInt16(1510),
        UInt16(1397),
        UInt16(1395),
        UInt16(1446),
        UInt16(660),
        UInt16(1399),
        UInt16(1288),
        UInt16(656),
        UInt16(657),
        UInt16(652),
        UInt16(655),
        UInt16(1457),
        UInt16(1458),
        UInt16(470),
        UInt16(386),
        UInt16(387),
        UInt16(481),
        UInt16(645),
        UInt16(636),
        UInt16(637),
        UInt16(685),
        UInt16(629),
        UInt16(638),
        UInt16(630),
        UInt16(624),
        UInt16(686),
        UInt16(59),
        UInt16(1032),
        UInt16(1031),
        UInt16(58),
        UInt16(849),
        UInt16(643),
        UInt16(654),
        UInt16(646),
        UInt16(647),
        UInt16(648),
        UInt16(1326),
        UInt16(2244),
        UInt16(1509),
        UInt16(1398),
        UInt16(1396),
        UInt16(1447),
    ]

    comptime _FIXED_COUNTER: InlineArray[Optional[UInt8], 103] = [
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

    comptime _FALLBACK: InlineArray[Optional[StaticString], 103] = [
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

    comptime _ALIAS: InlineArray[Optional[StaticString], 103] = [
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
