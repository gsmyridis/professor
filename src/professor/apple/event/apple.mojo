from professor.apple.cpu import Cpu

from .event import Event
from .cpu import CpuEvent


@fieldwise_init
struct AppleEvent(
    Equatable, Event, ImplicitlyCopyable, RegisterPassable, Writable
):
    """A hardware performance counter event from Apple's kpep database.

    Chip-agnostic identifier covering Apple Silicon generations M1
    through M5. Each variant holds its kpep event name and a bitmask of
    the generations that provide it; use `on(cpu)` to resolve it for a
    specific `Cpu`.
    """

    var _name: StaticString
    var _chips: UInt8

    comptime _M1 = UInt8(1 << Cpu.M1._tag)
    comptime _M2 = UInt8(1 << Cpu.M2._tag)
    comptime _M3 = UInt8(1 << Cpu.M3._tag)
    comptime _M4 = UInt8(1 << Cpu.M4._tag)
    comptime _M5 = UInt8(1 << Cpu.M5._tag)
    comptime _ALL = Self._M1 | Self._M2 | Self._M3 | Self._M4 | Self._M5

    comptime ArmBrMisPred = Self("ARM_BR_MIS_PRED", Self._M4 | Self._M5)
    """Mispredicted or not predicted branch Speculatively executed. Only
    available on M4 and M5."""

    comptime ArmBrPred = Self("ARM_BR_PRED", Self._M4 | Self._M5)
    """Predictable branch Speculatively executed. Only available on M4 and
    M5."""

    comptime ArmL1DCache = Self("ARM_L1D_CACHE", Self._M4 | Self._M5)
    """Level 1 data cache access. Only available on M4 and M5."""

    comptime ArmL1DCacheLmissRd = Self(
        "ARM_L1D_CACHE_LMISS_RD", Self._M4 | Self._M5
    )
    """Level 1 data cache long-latency read miss. Only available on M4 and
    M5."""

    comptime ArmL1DCacheRd = Self("ARM_L1D_CACHE_RD", Self._M4 | Self._M5)
    """Attributable Level 1 data cache access, read. Only available on M4
    and M5."""

    comptime ArmL1DCacheRefill = Self(
        "ARM_L1D_CACHE_REFILL", Self._M4 | Self._M5
    )
    """Level 1 data cache refill. Only available on M4 and M5."""

    comptime ArmStall = Self("ARM_STALL", Self._M4 | Self._M5)
    """No operation sent for execution. Only available on M4 and M5."""

    comptime ArmStallBackend = Self("ARM_STALL_BACKEND", Self._M4 | Self._M5)
    """No operation issued due to the backend. Only available on M4 and M5."""

    comptime ArmStallFrontend = Self("ARM_STALL_FRONTEND", Self._M4 | Self._M5)
    """No operation issued due to the frontend. Only available on M4 and M5."""

    comptime ArmStallSlot = Self("ARM_STALL_SLOT", Self._M4 | Self._M5)
    """No operation sent for execution on a slot. Only available on M4 and
    M5."""

    comptime ArmStallSlotBackend = Self(
        "ARM_STALL_SLOT_BACKEND", Self._M4 | Self._M5
    )
    """No operation sent for execution on a Slot due to the backend. Only
    available on M4 and M5."""

    comptime ArmStallSlotFrontend = Self(
        "ARM_STALL_SLOT_FRONTEND", Self._M4 | Self._M5
    )
    """No operation sent for execution on a Slot due to the frontend. Only
    available on M4 and M5."""

    comptime AtomicOrExclusiveFail = Self("ATOMIC_OR_EXCLUSIVE_FAIL", Self._ALL)
    """Atomic or exclusive instruction failed due to contention (for
    exclusives, incorrectly undercounts for exclusives when the cache line
    is initially found in shared state, however counts correctly for
    atomics)."""

    comptime AtomicOrExclusiveSucc = Self("ATOMIC_OR_EXCLUSIVE_SUCC", Self._ALL)
    """Atomic or exclusive instruction successfully completed (for
    exclusives, incorrectly undercounts for exclusives when the cache line
    is initially found in shared state, however counts correctly for
    atomics)."""

    comptime BranchCallIndirMispredNonspec = Self(
        "BRANCH_CALL_INDIR_MISPRED_NONSPEC", Self._ALL
    )
    """Retired indirect call instructions mispredicted."""

    comptime BranchCondMispredNonspec = Self(
        "BRANCH_COND_MISPRED_NONSPEC", Self._ALL
    )
    """Retired conditional branch instructions that mispredicted."""

    comptime BranchIndirMispredNonspec = Self(
        "BRANCH_INDIR_MISPRED_NONSPEC", Self._ALL
    )
    """Retired indirect branch instructions including calls and returns that
    mispredicted."""

    comptime BranchMispredNonspec = Self("BRANCH_MISPRED_NONSPEC", Self._ALL)
    """Instruction architecturally executed, mispredicted branch."""

    comptime BranchRetIndirMispredNonspec = Self(
        "BRANCH_RET_INDIR_MISPRED_NONSPEC", Self._ALL
    )
    """Retired return instructions that mispredicted."""

    comptime CoreActiveCycle = Self("CORE_ACTIVE_CYCLE", Self._ALL)
    """Cycles while the core was active."""

    comptime FetchRestart = Self("FETCH_RESTART", Self._ALL)
    """Fetch Unit internal restarts for any reason. Does not include branch
    mispredicts."""

    comptime FixedCycles = Self("FIXED_CYCLES", Self._ALL)
    """Cycles, counted on fixed counter 0. kpep alias: `Cycles`."""

    comptime Cycles = Self.FixedCycles
    """Alias for `FixedCycles`, matching the kpep alias `"Cycles"`."""

    comptime FixedInstructions = Self("FIXED_INSTRUCTIONS", Self._ALL)
    """Retired instructions, counted on fixed counter 1 (falls back to
    `INST_ALL`). kpep alias: `Instructions`."""

    comptime Instructions = Self.FixedInstructions
    """Alias for `FixedInstructions`, matching the kpep alias
    `"Instructions"`."""

    comptime FlushRestartOtherNonspec = Self(
        "FLUSH_RESTART_OTHER_NONSPEC", Self._ALL
    )
    """Pipeline flush and restarts that were not due to branch
    mispredictions or memory order violations."""

    comptime InstAll = Self("INST_ALL", Self._ALL)
    """All retired instructions."""

    comptime InstBarrier = Self("INST_BARRIER", Self._ALL)
    """Retired data barrier instructions."""

    comptime InstBranch = Self("INST_BRANCH", Self._ALL)
    """Retired branch instructions including calls and returns."""

    comptime InstBranchCall = Self("INST_BRANCH_CALL", Self._ALL)
    """Retired subroutine call instructions."""

    comptime InstBranchCond = Self("INST_BRANCH_COND", Self._M4 | Self._M5)
    """Retired conditional branch instructions (on M3 and prior, incorrectly
    only counts only B.cond instructions, where on M4 and following, adds
    CBZ/CBNZ/TBZ/TBNZ instructions to form the complete set of conditional
    branch instructions). Only available on M4 and M5."""

    comptime InstBranchIndir = Self("INST_BRANCH_INDIR", Self._ALL)
    """Retired indirect branch instructions including indirect calls."""

    comptime InstBranchRet = Self("INST_BRANCH_RET", Self._ALL)
    """Retired subroutine return instructions."""

    comptime InstBranchTaken = Self("INST_BRANCH_TAKEN", Self._ALL)
    """Retired taken branch instructions."""

    comptime InstIntAlu = Self("INST_INT_ALU", Self._ALL)
    """Retired non-branch and non-load/store Integer Unit instructions."""

    comptime InstIntLd = Self("INST_INT_LD", Self._ALL)
    """Retired load Integer Unit instructions."""

    comptime InstIntSt = Self("INST_INT_ST", Self._ALL)
    """Retired store Integer Unit instructions; does not count DC ZVA (Data
    Cache Zero by VA)."""

    comptime InstLdst = Self("INST_LDST", Self._ALL)
    """Retired load and store instructions; does not count DC ZVA (Data
    Cache Zero by VA)."""

    comptime InstSimdAlu = Self("INST_SIMD_ALU", Self._ALL)
    """Retired non-load/store Advanced SIMD and FP Unit instructions."""

    comptime InstSimdAluVec = Self(
        "INST_SIMD_ALU_VEC", Self._M2 | Self._M3 | Self._M4 | Self._M5
    )
    """Retired non-load/store vector Advanced SIMD  instructions. Only
    available on M2, M3, M4 and M5."""

    comptime InstSimdLd = Self("INST_SIMD_LD", Self._ALL)
    """Retired load Advanced SIMD and FP Unit instructions."""

    comptime InstSimdSt = Self("INST_SIMD_ST", Self._ALL)
    """Retired store Advanced SIMD and FP Unit instructions."""

    comptime InstSmeEngineAlu = Self("INST_SME_ENGINE_ALU", Self._M4 | Self._M5)
    """Retired non-load/store SME engine instructions. Only available on M4
    and M5."""

    comptime InstSmeEngineLd = Self("INST_SME_ENGINE_LD", Self._M4 | Self._M5)
    """Retired load SME engine instructions. Only available on M4 and M5."""

    comptime InstSmeEnginePackingFused = Self(
        "INST_SME_ENGINE_PACKING_FUSED", Self._M4 | Self._M5
    )
    """Retired non-load/store SME engine instructions that were packed with
    another to reduce instruction bandwidth to the SME engine. Only
    available on M4 and M5."""

    comptime InstSmeEngineScalarfp = Self(
        "INST_SME_ENGINE_SCALARFP", Self._M4 | Self._M5
    )
    """Retired scalar floating-point SME engine instructions. Only available
    on M4 and M5."""

    comptime InstSmeEngineSt = Self("INST_SME_ENGINE_ST", Self._M4 | Self._M5)
    """Retired store SME engine instructions. Only available on M4 and M5."""

    comptime InterruptPending = Self("INTERRUPT_PENDING", Self._ALL)
    """Cycles while an interrupt was pending because it was masked."""

    comptime L1DCacheMissLd = Self("L1D_CACHE_MISS_LD", Self._ALL)
    """Loads that missed the L1 Data Cache."""

    comptime L1DCacheMissLdNonspec = Self(
        "L1D_CACHE_MISS_LD_NONSPEC", Self._ALL
    )
    """Retired loads that missed in the L1 Data Cache."""

    comptime L1DCacheMissSt = Self("L1D_CACHE_MISS_ST", Self._ALL)
    """Stores that missed the L1 Data Cache."""

    comptime L1DCacheMissStNonspec = Self(
        "L1D_CACHE_MISS_ST_NONSPEC", Self._ALL
    )
    """Retired stores that missed in the L1 Data Cache."""

    comptime L1DCacheWriteback = Self("L1D_CACHE_WRITEBACK", Self._ALL)
    """Dirty cache lines written back from the L1D Cache toward the Shared
    L2 Cache."""

    comptime L1DTlbAccess = Self("L1D_TLB_ACCESS", Self._ALL)
    """Load and store accesses to the L1 Data TLB."""

    comptime L1DTlbFill = Self("L1D_TLB_FILL", Self._ALL)
    """Translations filled into the L1 Data TLB."""

    comptime L1DTlbMiss = Self("L1D_TLB_MISS", Self._ALL)
    """Load and store accesses that missed the L1 Data TLB."""

    comptime L1DTlbMissNonspec = Self("L1D_TLB_MISS_NONSPEC", Self._ALL)
    """Retired loads and stores that missed in the L1 Data TLB."""

    comptime L1ICacheMissDemand = Self("L1I_CACHE_MISS_DEMAND", Self._ALL)
    """Demand fetch misses that require a new cache line fill of the L1
    Instruction Cache."""

    comptime L1ITlbFill = Self("L1I_TLB_FILL", Self._ALL)
    """Translations filled into the L1 Instruction TLB."""

    comptime L1ITlbMissDemand = Self("L1I_TLB_MISS_DEMAND", Self._ALL)
    """Demand instruction fetches that missed in the L1 Instruction TLB."""

    comptime L2TlbMissData = Self("L2_TLB_MISS_DATA", Self._ALL)
    """Loads and stores that missed in the L2 TLB."""

    comptime L2TlbMissInstruction = Self("L2_TLB_MISS_INSTRUCTION", Self._ALL)
    """Instruction fetches that missed in the L2 TLB."""

    comptime LdBlockedBySmeLdst = Self(
        "LD_BLOCKED_BY_SME_LDST", Self._M4 | Self._M5
    )
    """Core load uops blocked by SME accesses to same 4KiB page. Only
    available on M4 and M5."""

    comptime LdNtUop = Self("LD_NT_UOP", Self._ALL)
    """Load uops that executed with non-temporal hint; excludes SSVE/SME
    loads because they utilize the Store Unit."""

    comptime LdSmeNormalUop = Self("LD_SME_NORMAL_UOP", Self._M4 | Self._M5)
    """SME engine load uops with Normal memory type. Only available on M4
    and M5."""

    comptime LdSmeNtUop = Self("LD_SME_NT_UOP", Self._M4 | Self._M5)
    """SME engine load uops that executed with non-temporal hint. Only
    available on M4 and M5."""

    comptime LdUnitUop = Self("LD_UNIT_UOP", Self._ALL)
    """Uops that flowed through the Load Unit."""

    comptime LdUnitWaitingYoungL1DCacheMiss = Self(
        "LD_UNIT_WAITING_YOUNG_L1D_CACHE_MISS", Self._M4 | Self._M5
    )
    """Cycles while a younger load uop is waiting for data after an L1 Data
    Cache miss, and no uop was issued by the scheduler with no critical
    miss, prioritized. Only available on M4 and M5."""

    comptime LdstSmePredInactive = Self(
        "LDST_SME_PRED_INACTIVE", Self._M4 | Self._M5
    )
    """SME engine load and store uops where all lanes are inactive due to
    the governing predicate; for a page-crossing load or store, the event
    may incorrectly count when all of the elements of the low page are
    predicated off, even if some of the elements on the high page are
    active. In Apple silicon cores, where predication is recommend primarily
    for data structure edge control (discarding elements 'past the end of
    the data structure'), this scenario should not be common. Only available
    on M4 and M5."""

    comptime LdstSmeXpgUop = Self("LDST_SME_XPG_UOP", Self._M4 | Self._M5)
    """SME engine load and store accesses that crossed a 16KiB page
    boundary; an access is considered cross-page if any bytes are accessed
    in the high portion (second page), regardless if any bytes are accessed
    in the low portion (first page), after predication is applied. An SME
    operation that only touches the low portion (first page) after
    predication is applied is not considered cross-page. Only available on
    M4 and M5."""

    comptime LdstUnitOldL1DCacheMiss = Self(
        "LDST_UNIT_OLD_L1D_CACHE_MISS", Self._M3 | Self._M4 | Self._M5
    )
    """Cycles while an old load or store uop is waiting for data after an L1
    Data Cache miss. Only available on M3, M4 and M5."""

    comptime LdstUnitWaitingOldL1DCacheMiss = Self(
        "LDST_UNIT_WAITING_OLD_L1D_CACHE_MISS", Self._M3 | Self._M4 | Self._M5
    )
    """Cycles while an old load or store uop is waiting for data after an L1
    Data Cache miss, and no uop was issued by the scheduler, prioritized.
    Only available on M3, M4 and M5."""

    comptime LdstUnitWaitingSmeEngineInstQueueFull = Self(
        "LDST_UNIT_WAITING_SME_ENGINE_INST_QUEUE_FULL", Self._M4 | Self._M5
    )
    """Cycles while the instruction queue to the SME engine is full, and no
    uop was issued by the scheduler with no critical miss, prioritized. Only
    available on M4 and M5."""

    comptime LdstUnitWaitingSmeEngineMemData = Self(
        "LDST_UNIT_WAITING_SME_ENGINE_MEM_DATA", Self._M4 | Self._M5
    )
    """Cycles while the core is waiting for the SME engine to produce memory
    data, and no uop was issued by the scheduler, prioritized. Only
    available on M4 and M5."""

    comptime LdstX64Uop = Self("LDST_X64_UOP", Self._ALL)
    """Load and store uops that crossed a 64B boundary."""

    comptime LdstXpgUop = Self("LDST_XPG_UOP", Self._ALL)
    """Load and store uops that crossed a 16KiB page boundary; an SME access
    is considered cross-page if any bytes are accessed in the high portion
    (second page), regardless if any bytes are accessed in the low portion
    (first page), after predication is applied. An SME operation that only
    touches the low portion (first page) after predication is applied is not
    considered cross-page."""

    comptime MapDispatchBubble = Self("MAP_DISPATCH_BUBBLE", Self._ALL)
    """Cycles while the Map Unit had no uops to process and was not stalled."""

    comptime MapDispatchBubbleIc = Self(
        "MAP_DISPATCH_BUBBLE_IC", Self._M3 | Self._M4 | Self._M5
    )
    """Cycles while the Map Unit had no uops to process due to L1
    Instruction Cache and was not stalled. Only available on M3, M4 and M5."""

    comptime MapDispatchBubbleItlb = Self(
        "MAP_DISPATCH_BUBBLE_ITLB", Self._M3 | Self._M4 | Self._M5
    )
    """Cycles while the Map Unit had no uops to process due to L1
    Instruction TLB and was not stalled. Only available on M3, M4 and M5."""

    comptime MapDispatchBubbleSlot = Self(
        "MAP_DISPATCH_BUBBLE_SLOT", Self._M4 | Self._M5
    )
    """Slots where the Map Unit had no uops to process and was not stalled.
    Only available on M4 and M5."""

    comptime MapIntSmeUop = Self("MAP_INT_SME_UOP", Self._M4 | Self._M5)
    """Mapped core Integer Unit uops for SME engine instructions. Only
    available on M4 and M5."""

    comptime MapIntUop = Self("MAP_INT_UOP", Self._ALL)
    """Mapped Integer Unit uops."""

    comptime MapLdstUop = Self("MAP_LDST_UOP", Self._ALL)
    """Mapped Load and Store Unit uops, including GPR to vector register
    converts; includes all instructions sent to the SME engine because they
    are processed through the Store Unit."""

    comptime MapRecovery = Self("MAP_RECOVERY", Self._M4 | Self._M5)
    """Cycles while the Map Unit was stalled while recovering from a flush
    and restart. Only available on M4 and M5."""

    comptime MapRewind = Self("MAP_REWIND", Self._ALL)
    """Cycles while the Map Unit was blocked while rewinding due to flush
    and restart."""

    comptime MapSimdUop = Self("MAP_SIMD_UOP", Self._ALL)
    """Mapped Advanced SIMD and FP Unit uops."""

    comptime MapStall = Self("MAP_STALL", Self._ALL)
    """Cycles while the Map Unit was stalled for any reason."""

    comptime MapStallDispatch = Self("MAP_STALL_DISPATCH", Self._ALL)
    """Cycles while the Map Unit was stalled because of Dispatch back
    pressure."""

    comptime MapStallNonrecovery = Self(
        "MAP_STALL_NONRECOVERY", Self._M4 | Self._M5
    )
    """Cycles while the Map Unit was stalled for any reason other than
    recovery. Only available on M4 and M5."""

    comptime MapUop = Self("MAP_UOP", Self._M3 | Self._M4 | Self._M5)
    """Mapped uops. Only available on M3, M4 and M5."""

    comptime MmuTableWalkData = Self("MMU_TABLE_WALK_DATA", Self._ALL)
    """Table walk memory requests on behalf of data accesses."""

    comptime MmuTableWalkInstruction = Self(
        "MMU_TABLE_WALK_INSTRUCTION", Self._ALL
    )
    """Table walk memory requests on behalf of instruction fetches."""

    comptime RetireUop = Self("RETIRE_UOP", Self._ALL)
    """All retired uops."""

    comptime ScheduleEmpty = Self("SCHEDULE_EMPTY", Self._ALL)
    """Cycles while the uop scheduler is empty."""

    comptime ScheduleUop = Self("SCHEDULE_UOP", Self._M1)
    """Uops issued by the scheduler to any execution unit. Only available on
    M1."""

    comptime ScheduleWaitingSmeEngineRegData = Self(
        "SCHEDULE_WAITING_SME_ENGINE_REG_DATA", Self._M4 | Self._M5
    )
    """Cycles while the core is waiting for register, predicate, or flag
    data from the SME engine, and no uop was issued by the scheduler with no
    critical miss, prioritized. Only available on M4 and M5."""

    comptime SmeEngineSmEnable = Self(
        "SME_ENGINE_SM_ENABLE", Self._M4 | Self._M5
    )
    """Transitions into SME engine Streaming Mode (PSTATE.SM: 0 to 1). Only
    available on M4 and M5."""

    comptime SmeEngineSmZaEnable = Self(
        "SME_ENGINE_SM_ZA_ENABLE", Self._M4 | Self._M5
    )
    """Simultaneous transitions into SME engine Streaming Mode and ZA Mode
    (PSTATE.SM: 0 to 1 and PSTATE.ZA: 0 to 1). Only available on M4 and M5."""

    comptime SmeEngineZaEnabledSmDisabled = Self(
        "SME_ENGINE_ZA_ENABLED_SM_DISABLED", Self._M4 | Self._M5
    )
    """Cycles while SME engine ZA Mode is enabled but Streaming Mode is not
    (PSTATE.ZA=1 and PSTATE.SM=0). Only available on M4 and M5."""

    comptime StBarrierBlockedBySmeLdst = Self(
        "ST_BARRIER_BLOCKED_BY_SME_LDST", Self._M4 | Self._M5
    )
    """Core store uops blocked by SME accesses to same 4KiB page, and any
    barriers or store-release uops blocked by SME accesses. Only available
    on M4 and M5."""

    comptime StMemOrderViolLdNonspec = Self(
        "ST_MEM_ORDER_VIOL_LD_NONSPEC", Self._ALL
    )
    """Retired core store uops that triggered memory order violations with
    core load uops."""

    comptime StNtUop = Self("ST_NT_UOP", Self._ALL)
    """Store uops that executed with non-temporal hint; includes SSVE/SME
    loads because they utilize the Store Unit."""

    comptime StSmeNormalUop = Self("ST_SME_NORMAL_UOP", Self._M4 | Self._M5)
    """SME engine store uops with Normal memory type. Only available on M4
    and M5."""

    comptime StSmeNtUop = Self("ST_SME_NT_UOP", Self._M4 | Self._M5)
    """SME engine store uops that executed with non-temporal hint. Only
    available on M4 and M5."""

    comptime StUnitUop = Self("ST_UNIT_UOP", Self._ALL)
    """Uops that flowed through the Store Unit."""

    # TODO: Reflection-synthesized `Equatable` currently miscompiles on
    # `StringSlice` fields (kgen.struct.gep error in reflect.mojo); remove
    # the manual implementations once fixed upstream.
    def __eq__(self, other: Self) -> Bool:
        return self._name == other._name

    def __ne__(self, other: Self) -> Bool:
        return self._name != other._name

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self._name)

    def name(self) -> StaticString:
        """The kpep event name, e.g. `"INST_ALL"`."""
        return self._name

    def is_available_on(self, cpu: Cpu) -> Bool:
        """Whether this event exists on `cpu`'s generation."""
        return (self._chips >> cpu._tag) & 1 != 0

    def on(self, cpu: Cpu) -> Optional[CpuEvent]:
        """Resolves this event for `cpu`, or `None` if unavailable there."""
        if self.is_available_on(cpu):
            return CpuEvent(cpu, self._name)
        return None
