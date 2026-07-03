from .event import Event


@fieldwise_init
struct M4Event(
    Equatable, Event, ImplicitlyCopyable, RegisterPassable, Writable
):
    """Hardware performance counter events available on M4.

    Each variant holds its kpep event name, which keys into the kpep
    database; all other event metadata is runtime information owned by
    `Database`.
    """

    var _name: StaticString

    comptime ArmBrMisPred = Self("ARM_BR_MIS_PRED")
    """Mispredicted or not predicted branch Speculatively executed."""

    comptime ArmBrPred = Self("ARM_BR_PRED")
    """Predictable branch Speculatively executed."""

    comptime ArmL1DCache = Self("ARM_L1D_CACHE")
    """Level 1 data cache access."""

    comptime ArmL1DCacheLmissRd = Self("ARM_L1D_CACHE_LMISS_RD")
    """Level 1 data cache long-latency read miss."""

    comptime ArmL1DCacheRd = Self("ARM_L1D_CACHE_RD")
    """Attributable Level 1 data cache access, read."""

    comptime ArmL1DCacheRefill = Self("ARM_L1D_CACHE_REFILL")
    """Level 1 data cache refill."""

    comptime ArmStall = Self("ARM_STALL")
    """No operation sent for execution."""

    comptime ArmStallBackend = Self("ARM_STALL_BACKEND")
    """No operation issued due to the backend."""

    comptime ArmStallFrontend = Self("ARM_STALL_FRONTEND")
    """No operation issued due to the frontend."""

    comptime ArmStallSlot = Self("ARM_STALL_SLOT")
    """No operation sent for execution on a slot."""

    comptime ArmStallSlotBackend = Self("ARM_STALL_SLOT_BACKEND")
    """No operation sent for execution on a Slot due to the backend."""

    comptime ArmStallSlotFrontend = Self("ARM_STALL_SLOT_FRONTEND")
    """No operation sent for execution on a Slot due to the frontend."""

    comptime AtomicOrExclusiveFail = Self("ATOMIC_OR_EXCLUSIVE_FAIL")
    """Atomic or exclusive instruction failed due to contention (for
    exclusives, incorrectly undercounts for exclusives when the cache line
    is initially found in shared state, however counts correctly for
    atomics)."""

    comptime AtomicOrExclusiveSucc = Self("ATOMIC_OR_EXCLUSIVE_SUCC")
    """Atomic or exclusive instruction successfully completed (for
    exclusives, incorrectly undercounts for exclusives when the cache line
    is initially found in shared state, however counts correctly for
    atomics)."""

    comptime BranchCallIndirMispredNonspec = Self(
        "BRANCH_CALL_INDIR_MISPRED_NONSPEC"
    )
    """Retired indirect call instructions mispredicted."""

    comptime BranchCondMispredNonspec = Self("BRANCH_COND_MISPRED_NONSPEC")
    """Retired conditional branch instructions that mispredicted."""

    comptime BranchIndirMispredNonspec = Self("BRANCH_INDIR_MISPRED_NONSPEC")
    """Retired indirect branch instructions including calls and returns that
    mispredicted."""

    comptime BranchMispredNonspec = Self("BRANCH_MISPRED_NONSPEC")
    """Instruction architecturally executed, mispredicted branch."""

    comptime BranchRetIndirMispredNonspec = Self(
        "BRANCH_RET_INDIR_MISPRED_NONSPEC"
    )
    """Retired return instructions that mispredicted."""

    comptime CoreActiveCycle = Self("CORE_ACTIVE_CYCLE")
    """Cycles while the core was active."""

    comptime FetchRestart = Self("FETCH_RESTART")
    """Fetch Unit internal restarts for any reason. Does not include branch
    mispredicts."""

    comptime FixedCycles = Self("FIXED_CYCLES")
    """Cycles, counted on fixed counter 0. kpep alias: `Cycles`."""

    comptime Cycles = Self.FixedCycles
    """Alias for `FixedCycles`, matching the kpep alias `"Cycles"`."""

    comptime FixedInstructions = Self("FIXED_INSTRUCTIONS")
    """Retired instructions, counted on fixed counter 1 (falls back to
    `INST_ALL`). kpep alias: `Instructions`."""

    comptime Instructions = Self.FixedInstructions
    """Alias for `FixedInstructions`, matching the kpep alias
    `"Instructions"`."""

    comptime FlushRestartOtherNonspec = Self("FLUSH_RESTART_OTHER_NONSPEC")
    """Pipeline flush and restarts that were not due to branch
    mispredictions or memory order violations."""

    comptime InstAll = Self("INST_ALL")
    """All retired instructions."""

    comptime InstBarrier = Self("INST_BARRIER")
    """Retired data barrier instructions."""

    comptime InstBranch = Self("INST_BRANCH")
    """Retired branch instructions including calls and returns."""

    comptime InstBranchCall = Self("INST_BRANCH_CALL")
    """Retired subroutine call instructions."""

    comptime InstBranchCond = Self("INST_BRANCH_COND")
    """Retired conditional branch instructions (on M3 and prior, incorrectly
    only counts only B.cond instructions, where on M4 and following, adds
    CBZ/CBNZ/TBZ/TBNZ instructions to form the complete set of conditional
    branch instructions)."""

    comptime InstBranchIndir = Self("INST_BRANCH_INDIR")
    """Retired indirect branch instructions including indirect calls."""

    comptime InstBranchRet = Self("INST_BRANCH_RET")
    """Retired subroutine return instructions."""

    comptime InstBranchTaken = Self("INST_BRANCH_TAKEN")
    """Retired taken branch instructions."""

    comptime InstIntAlu = Self("INST_INT_ALU")
    """Retired non-branch and non-load/store Integer Unit instructions."""

    comptime InstIntLd = Self("INST_INT_LD")
    """Retired load Integer Unit instructions."""

    comptime InstIntSt = Self("INST_INT_ST")
    """Retired store Integer Unit instructions; does not count DC ZVA (Data
    Cache Zero by VA)."""

    comptime InstLdst = Self("INST_LDST")
    """Retired load and store instructions; does not count DC ZVA (Data
    Cache Zero by VA)."""

    comptime InstSimdAlu = Self("INST_SIMD_ALU")
    """Retired non-load/store Advanced SIMD and FP Unit instructions."""

    comptime InstSimdAluVec = Self("INST_SIMD_ALU_VEC")
    """Retired non-load/store vector Advanced SIMD  instructions."""

    comptime InstSimdLd = Self("INST_SIMD_LD")
    """Retired load Advanced SIMD and FP Unit instructions."""

    comptime InstSimdSt = Self("INST_SIMD_ST")
    """Retired store Advanced SIMD and FP Unit instructions."""

    comptime InstSmeEngineAlu = Self("INST_SME_ENGINE_ALU")
    """Retired non-load/store SME engine instructions."""

    comptime InstSmeEngineLd = Self("INST_SME_ENGINE_LD")
    """Retired load SME engine instructions."""

    comptime InstSmeEnginePackingFused = Self("INST_SME_ENGINE_PACKING_FUSED")
    """Retired non-load/store SME engine instructions that were packed with
    another to reduce instruction bandwidth to the SME engine."""

    comptime InstSmeEngineScalarfp = Self("INST_SME_ENGINE_SCALARFP")
    """Retired scalar floating-point SME engine instructions."""

    comptime InstSmeEngineSt = Self("INST_SME_ENGINE_ST")
    """Retired store SME engine instructions."""

    comptime InterruptPending = Self("INTERRUPT_PENDING")
    """Cycles while an interrupt was pending because it was masked."""

    comptime L1DCacheMissLd = Self("L1D_CACHE_MISS_LD")
    """Loads that missed the L1 Data Cache."""

    comptime L1DCacheMissLdNonspec = Self("L1D_CACHE_MISS_LD_NONSPEC")
    """Retired loads that missed in the L1 Data Cache."""

    comptime L1DCacheMissSt = Self("L1D_CACHE_MISS_ST")
    """Stores that missed the L1 Data Cache."""

    comptime L1DCacheMissStNonspec = Self("L1D_CACHE_MISS_ST_NONSPEC")
    """Retired stores that missed in the L1 Data Cache."""

    comptime L1DCacheWriteback = Self("L1D_CACHE_WRITEBACK")
    """Dirty cache lines written back from the L1D Cache toward the Shared
    L2 Cache."""

    comptime L1DTlbAccess = Self("L1D_TLB_ACCESS")
    """Load and store accesses to the L1 Data TLB."""

    comptime L1DTlbFill = Self("L1D_TLB_FILL")
    """Translations filled into the L1 Data TLB."""

    comptime L1DTlbMiss = Self("L1D_TLB_MISS")
    """Load and store accesses that missed the L1 Data TLB."""

    comptime L1DTlbMissNonspec = Self("L1D_TLB_MISS_NONSPEC")
    """Retired loads and stores that missed in the L1 Data TLB."""

    comptime L1ICacheMissDemand = Self("L1I_CACHE_MISS_DEMAND")
    """Demand fetch misses that require a new cache line fill of the L1
    Instruction Cache."""

    comptime L1ITlbFill = Self("L1I_TLB_FILL")
    """Translations filled into the L1 Instruction TLB."""

    comptime L1ITlbMissDemand = Self("L1I_TLB_MISS_DEMAND")
    """Demand instruction fetches that missed in the L1 Instruction TLB."""

    comptime L2TlbMissData = Self("L2_TLB_MISS_DATA")
    """Loads and stores that missed in the L2 TLB."""

    comptime L2TlbMissInstruction = Self("L2_TLB_MISS_INSTRUCTION")
    """Instruction fetches that missed in the L2 TLB."""

    comptime LdBlockedBySmeLdst = Self("LD_BLOCKED_BY_SME_LDST")
    """Core load uops blocked by SME accesses to same 4KiB page."""

    comptime LdNtUop = Self("LD_NT_UOP")
    """Load uops that executed with non-temporal hint; excludes SSVE/SME
    loads because they utilize the Store Unit."""

    comptime LdSmeNormalUop = Self("LD_SME_NORMAL_UOP")
    """SME engine load uops with Normal memory type."""

    comptime LdSmeNtUop = Self("LD_SME_NT_UOP")
    """SME engine load uops that executed with non-temporal hint."""

    comptime LdUnitUop = Self("LD_UNIT_UOP")
    """Uops that flowed through the Load Unit."""

    comptime LdUnitWaitingYoungL1DCacheMiss = Self(
        "LD_UNIT_WAITING_YOUNG_L1D_CACHE_MISS"
    )
    """Cycles while a younger load uop is waiting for data after an L1 Data
    Cache miss, and no uop was issued by the scheduler with no critical
    miss, prioritized."""

    comptime LdstSmePredInactive = Self("LDST_SME_PRED_INACTIVE")
    """SME engine load and store uops where all lanes are inactive due to
    the governing predicate; for a page-crossing load or store, the event
    may incorrectly count when all of the elements of the low page are
    predicated off, even if some of the elements on the high page are
    active. In Apple silicon cores, where predication is recommend primarily
    for data structure edge control (discarding elements 'past the end of
    the data structure'), this scenario should not be common."""

    comptime LdstSmeXpgUop = Self("LDST_SME_XPG_UOP")
    """SME engine load and store accesses that crossed a 16KiB page
    boundary; an access is considered cross-page if any bytes are accessed
    in the high portion (second page), regardless if any bytes are accessed
    in the low portion (first page), after predication is applied. An SME
    operation that only touches the low portion (first page) after
    predication is applied is not considered cross-page."""

    comptime LdstUnitOldL1DCacheMiss = Self("LDST_UNIT_OLD_L1D_CACHE_MISS")
    """Cycles while an old load or store uop is waiting for data after an L1
    Data Cache miss."""

    comptime LdstUnitWaitingOldL1DCacheMiss = Self(
        "LDST_UNIT_WAITING_OLD_L1D_CACHE_MISS"
    )
    """Cycles while an old load or store uop is waiting for data after an L1
    Data Cache miss, and no uop was issued by the scheduler, prioritized."""

    comptime LdstUnitWaitingSmeEngineInstQueueFull = Self(
        "LDST_UNIT_WAITING_SME_ENGINE_INST_QUEUE_FULL"
    )
    """Cycles while the instruction queue to the SME engine is full, and no
    uop was issued by the scheduler with no critical miss, prioritized."""

    comptime LdstUnitWaitingSmeEngineMemData = Self(
        "LDST_UNIT_WAITING_SME_ENGINE_MEM_DATA"
    )
    """Cycles while the core is waiting for the SME engine to produce memory
    data, and no uop was issued by the scheduler, prioritized."""

    comptime LdstX64Uop = Self("LDST_X64_UOP")
    """Load and store uops that crossed a 64B boundary."""

    comptime LdstXpgUop = Self("LDST_XPG_UOP")
    """Load and store uops that crossed a 16KiB page boundary; an SME access
    is considered cross-page if any bytes are accessed in the high portion
    (second page), regardless if any bytes are accessed in the low portion
    (first page), after predication is applied. An SME operation that only
    touches the low portion (first page) after predication is applied is not
    considered cross-page."""

    comptime MapDispatchBubble = Self("MAP_DISPATCH_BUBBLE")
    """Cycles while the Map Unit had no uops to process and was not stalled."""

    comptime MapDispatchBubbleIc = Self("MAP_DISPATCH_BUBBLE_IC")
    """Cycles while the Map Unit had no uops to process due to L1
    Instruction Cache and was not stalled."""

    comptime MapDispatchBubbleItlb = Self("MAP_DISPATCH_BUBBLE_ITLB")
    """Cycles while the Map Unit had no uops to process due to L1
    Instruction TLB and was not stalled."""

    comptime MapDispatchBubbleSlot = Self("MAP_DISPATCH_BUBBLE_SLOT")
    """Slots where the Map Unit had no uops to process and was not stalled."""

    comptime MapIntSmeUop = Self("MAP_INT_SME_UOP")
    """Mapped core Integer Unit uops for SME engine instructions."""

    comptime MapIntUop = Self("MAP_INT_UOP")
    """Mapped Integer Unit uops."""

    comptime MapLdstUop = Self("MAP_LDST_UOP")
    """Mapped Load and Store Unit uops, including GPR to vector register
    converts; includes all instructions sent to the SME engine because they
    are processed through the Store Unit."""

    comptime MapRecovery = Self("MAP_RECOVERY")
    """Cycles while the Map Unit was stalled while recovering from a flush
    and restart."""

    comptime MapRewind = Self("MAP_REWIND")
    """Cycles while the Map Unit was blocked while rewinding due to flush
    and restart."""

    comptime MapSimdUop = Self("MAP_SIMD_UOP")
    """Mapped Advanced SIMD and FP Unit uops."""

    comptime MapStall = Self("MAP_STALL")
    """Cycles while the Map Unit was stalled for any reason."""

    comptime MapStallDispatch = Self("MAP_STALL_DISPATCH")
    """Cycles while the Map Unit was stalled because of Dispatch back
    pressure."""

    comptime MapStallNonrecovery = Self("MAP_STALL_NONRECOVERY")
    """Cycles while the Map Unit was stalled for any reason other than
    recovery."""

    comptime MapUop = Self("MAP_UOP")
    """Mapped uops."""

    comptime MmuTableWalkData = Self("MMU_TABLE_WALK_DATA")
    """Table walk memory requests on behalf of data accesses."""

    comptime MmuTableWalkInstruction = Self("MMU_TABLE_WALK_INSTRUCTION")
    """Table walk memory requests on behalf of instruction fetches."""

    comptime RetireUop = Self("RETIRE_UOP")
    """All retired uops."""

    comptime ScheduleEmpty = Self("SCHEDULE_EMPTY")
    """Cycles while the uop scheduler is empty."""

    comptime ScheduleUop = Self("SCHEDULE_UOP_ANY")
    """Cycles while the uop scheduler issued at least 1 uop to any execution
    unit."""

    comptime ScheduleWaitingSmeEngineRegData = Self(
        "SCHEDULE_WAITING_SME_ENGINE_REG_DATA"
    )
    """Cycles while the core is waiting for register, predicate, or flag
    data from the SME engine, and no uop was issued by the scheduler with no
    critical miss, prioritized."""

    comptime SmeEngineSmEnable = Self("SME_ENGINE_SM_ENABLE")
    """Transitions into SME engine Streaming Mode (PSTATE.SM: 0 to 1)."""

    comptime SmeEngineSmZaEnable = Self("SME_ENGINE_SM_ZA_ENABLE")
    """Simultaneous transitions into SME engine Streaming Mode and ZA Mode
    (PSTATE.SM: 0 to 1 and PSTATE.ZA: 0 to 1)."""

    comptime SmeEngineZaEnabledSmDisabled = Self(
        "SME_ENGINE_ZA_ENABLED_SM_DISABLED"
    )
    """Cycles while SME engine ZA Mode is enabled but Streaming Mode is not
    (PSTATE.ZA=1 and PSTATE.SM=0)."""

    comptime StBarrierBlockedBySmeLdst = Self("ST_BARRIER_BLOCKED_BY_SME_LDST")
    """Core store uops blocked by SME accesses to same 4KiB page, and any
    barriers or store-release uops blocked by SME accesses."""

    comptime StMemOrderViolLdNonspec = Self("ST_MEM_ORDER_VIOL_LD_NONSPEC")
    """Retired core store uops that triggered memory order violations with
    core load uops."""

    comptime StNtUop = Self("ST_NT_UOP")
    """Store uops that executed with non-temporal hint; includes SSVE/SME
    loads because they utilize the Store Unit."""

    comptime StSmeNormalUop = Self("ST_SME_NORMAL_UOP")
    """SME engine store uops with Normal memory type."""

    comptime StSmeNtUop = Self("ST_SME_NT_UOP")
    """SME engine store uops that executed with non-temporal hint."""

    comptime StUnitUop = Self("ST_UNIT_UOP")
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
