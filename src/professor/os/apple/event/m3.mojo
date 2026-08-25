from professor.os.event import Event


struct M3Event(
    Equatable, Event, ImplicitlyCopyable, RegisterPassable, Writable
):
    """Hardware performance counter events available on M3.

    Each variant holds its kpep event name, which keys into the kpep
    database; all other event metadata is runtime information owned by
    `Database`.
    """

    var _name: StaticString

    @doc_hidden
    def __init__(out self, *, _name: StaticString):
        self._name = _name

    comptime AtomicOrExclusiveFail = Self(_name="ATOMIC_OR_EXCLUSIVE_FAIL")
    """Atomic or exclusive instruction failed due to contention (for
    exclusives, incorrectly undercounts for exclusives when the cache line
    is initially found in shared state, however counts correctly for
    atomics)."""

    comptime AtomicOrExclusiveSucc = Self(_name="ATOMIC_OR_EXCLUSIVE_SUCC")
    """Atomic or exclusive instruction successfully completed (for
    exclusives, incorrectly undercounts for exclusives when the cache line
    is initially found in shared state, however counts correctly for
    atomics)."""

    comptime BranchCallIndirMispredNonspec = Self(
        _name="BRANCH_CALL_INDIR_MISPRED_NONSPEC"
    )
    """Retired indirect call instructions mispredicted."""

    comptime BranchCondMispredNonspec = Self(
        _name="BRANCH_COND_MISPRED_NONSPEC"
    )
    """Retired conditional branch instructions that mispredicted."""

    comptime BranchIndirMispredNonspec = Self(
        _name="BRANCH_INDIR_MISPRED_NONSPEC"
    )
    """Retired indirect branch instructions including calls and returns that
    mispredicted."""

    comptime BranchMispredNonspec = Self(_name="BRANCH_MISPRED_NONSPEC")
    """Instruction architecturally executed, mispredicted branch."""

    comptime BranchRetIndirMispredNonspec = Self(
        _name="BRANCH_RET_INDIR_MISPRED_NONSPEC"
    )
    """Retired return instructions that mispredicted."""

    comptime CoreActiveCycle = Self(_name="CORE_ACTIVE_CYCLE")
    """Cycles while the core was active."""

    comptime FetchRestart = Self(_name="FETCH_RESTART")
    """Fetch Unit internal restarts for any reason. Does not include branch
    mispredicts."""

    comptime FixedCycles = Self(_name="FIXED_CYCLES")
    """Cycles, counted on fixed counter 0. kpep alias: `Cycles`."""

    comptime Cycles = Self.FixedCycles
    """Alias for `FixedCycles`, matching the kpep alias `"Cycles"`."""

    comptime FixedInstructions = Self(_name="FIXED_INSTRUCTIONS")
    """Retired instructions, counted on fixed counter 1 (falls back to
    `INST_ALL`). kpep alias: `Instructions`."""

    comptime Instructions = Self.FixedInstructions
    """Alias for `FixedInstructions`, matching the kpep alias
    `"Instructions"`."""

    comptime FlushRestartOtherNonspec = Self(
        _name="FLUSH_RESTART_OTHER_NONSPEC"
    )
    """Pipeline flush and restarts that were not due to branch
    mispredictions or memory order violations."""

    comptime InstAll = Self(_name="INST_ALL")
    """All retired instructions."""

    comptime InstBarrier = Self(_name="INST_BARRIER")
    """Retired data barrier instructions."""

    comptime InstBranch = Self(_name="INST_BRANCH")
    """Retired branch instructions including calls and returns."""

    comptime InstBranchCall = Self(_name="INST_BRANCH_CALL")
    """Retired subroutine call instructions."""

    comptime InstBranchIndir = Self(_name="INST_BRANCH_INDIR")
    """Retired indirect branch instructions including indirect calls."""

    comptime InstBranchRet = Self(_name="INST_BRANCH_RET")
    """Retired subroutine return instructions."""

    comptime InstBranchTaken = Self(_name="INST_BRANCH_TAKEN")
    """Retired taken branch instructions."""

    comptime InstIntAlu = Self(_name="INST_INT_ALU")
    """Retired non-branch and non-load/store Integer Unit instructions."""

    comptime InstIntLd = Self(_name="INST_INT_LD")
    """Retired load Integer Unit instructions."""

    comptime InstIntSt = Self(_name="INST_INT_ST")
    """Retired store Integer Unit instructions; does not count DC ZVA (Data
    Cache Zero by VA)."""

    comptime InstLdst = Self(_name="INST_LDST")
    """Retired load and store instructions; does not count DC ZVA (Data
    Cache Zero by VA)."""

    comptime InstSimdAlu = Self(_name="INST_SIMD_ALU")
    """Retired non-load/store Advanced SIMD and FP Unit instructions."""

    comptime InstSimdAluVec = Self(_name="INST_SIMD_ALU_VEC")
    """Retired non-load/store vector Advanced SIMD  instructions."""

    comptime InstSimdLd = Self(_name="INST_SIMD_LD")
    """Retired load Advanced SIMD and FP Unit instructions."""

    comptime InstSimdSt = Self(_name="INST_SIMD_ST")
    """Retired store Advanced SIMD and FP Unit instructions."""

    comptime InterruptPending = Self(_name="INTERRUPT_PENDING")
    """Cycles while an interrupt was pending because it was masked."""

    comptime L1DCacheMissLd = Self(_name="L1D_CACHE_MISS_LD")
    """Loads that missed the L1 Data Cache."""

    comptime L1DCacheMissLdNonspec = Self(_name="L1D_CACHE_MISS_LD_NONSPEC")
    """Retired loads that missed in the L1 Data Cache."""

    comptime L1DCacheMissSt = Self(_name="L1D_CACHE_MISS_ST")
    """Stores that missed the L1 Data Cache."""

    comptime L1DCacheMissStNonspec = Self(_name="L1D_CACHE_MISS_ST_NONSPEC")
    """Retired stores that missed in the L1 Data Cache."""

    comptime L1DCacheWriteback = Self(_name="L1D_CACHE_WRITEBACK")
    """Dirty cache lines written back from the L1D Cache toward the Shared
    L2 Cache."""

    comptime L1DTlbAccess = Self(_name="L1D_TLB_ACCESS")
    """Load and store accesses to the L1 Data TLB."""

    comptime L1DTlbFill = Self(_name="L1D_TLB_FILL")
    """Translations filled into the L1 Data TLB."""

    comptime L1DTlbMiss = Self(_name="L1D_TLB_MISS")
    """Load and store accesses that missed the L1 Data TLB."""

    comptime L1DTlbMissNonspec = Self(_name="L1D_TLB_MISS_NONSPEC")
    """Retired loads and stores that missed in the L1 Data TLB."""

    comptime L1ICacheMissDemand = Self(_name="L1I_CACHE_MISS_DEMAND")
    """Demand fetch misses that require a new cache line fill of the L1
    Instruction Cache."""

    comptime L1ITlbFill = Self(_name="L1I_TLB_FILL")
    """Translations filled into the L1 Instruction TLB."""

    comptime L1ITlbMissDemand = Self(_name="L1I_TLB_MISS_DEMAND")
    """Demand instruction fetches that missed in the L1 Instruction TLB."""

    comptime L2TlbMissData = Self(_name="L2_TLB_MISS_DATA")
    """Loads and stores that missed in the L2 TLB."""

    comptime L2TlbMissInstruction = Self(_name="L2_TLB_MISS_INSTRUCTION")
    """Instruction fetches that missed in the L2 TLB."""

    comptime LdNtUop = Self(_name="LD_NT_UOP")
    """Load uops that executed with non-temporal hint; excludes SSVE/SME
    loads because they utilize the Store Unit."""

    comptime LdUnitUop = Self(_name="LD_UNIT_UOP")
    """Uops that flowed through the Load Unit."""

    comptime LdstUnitOldL1DCacheMiss = Self(
        _name="LDST_UNIT_OLD_L1D_CACHE_MISS"
    )
    """Cycles while an old load or store uop is waiting for data after an L1
    Data Cache miss."""

    comptime LdstUnitWaitingOldL1DCacheMiss = Self(
        _name="LDST_UNIT_WAITING_OLD_L1D_CACHE_MISS"
    )
    """Cycles while an old load or store uop is waiting for data after an L1
    Data Cache miss, and no uop was issued by the scheduler, prioritized."""

    comptime LdstX64Uop = Self(_name="LDST_X64_UOP")
    """Load and store uops that crossed a 64B boundary."""

    comptime LdstXpgUop = Self(_name="LDST_XPG_UOP")
    """Load and store uops that crossed a 16KiB page boundary; an SME access
    is considered cross-page if any bytes are accessed in the high portion
    (second page), regardless if any bytes are accessed in the low portion
    (first page), after predication is applied. An SME operation that only
    touches the low portion (first page) after predication is applied is not
    considered cross-page."""

    comptime MapDispatchBubble = Self(_name="MAP_DISPATCH_BUBBLE")
    """Cycles while the Map Unit had no uops to process and was not stalled."""

    comptime MapDispatchBubbleIc = Self(_name="MAP_DISPATCH_BUBBLE_IC")
    """Cycles while the Map Unit had no uops to process due to L1
    Instruction Cache and was not stalled."""

    comptime MapDispatchBubbleItlb = Self(_name="MAP_DISPATCH_BUBBLE_ITLB")
    """Cycles while the Map Unit had no uops to process due to L1
    Instruction TLB and was not stalled."""

    comptime MapIntUop = Self(_name="MAP_INT_UOP")
    """Mapped Integer Unit uops."""

    comptime MapLdstUop = Self(_name="MAP_LDST_UOP")
    """Mapped Load and Store Unit uops, including GPR to vector register
    converts; includes all instructions sent to the SME engine because they
    are processed through the Store Unit."""

    comptime MapRewind = Self(_name="MAP_REWIND")
    """Cycles while the Map Unit was blocked while rewinding due to flush
    and restart."""

    comptime MapSimdUop = Self(_name="MAP_SIMD_UOP")
    """Mapped Advanced SIMD and FP Unit uops."""

    comptime MapStall = Self(_name="MAP_STALL")
    """Cycles while the Map Unit was stalled for any reason."""

    comptime MapStallDispatch = Self(_name="MAP_STALL_DISPATCH")
    """Cycles while the Map Unit was stalled because of Dispatch back
    pressure."""

    comptime MapUop = Self(_name="MAP_UOP")
    """Mapped uops."""

    comptime MmuTableWalkData = Self(_name="MMU_TABLE_WALK_DATA")
    """Table walk memory requests on behalf of data accesses."""

    comptime MmuTableWalkInstruction = Self(_name="MMU_TABLE_WALK_INSTRUCTION")
    """Table walk memory requests on behalf of instruction fetches."""

    comptime RetireUop = Self(_name="RETIRE_UOP")
    """All retired uops."""

    comptime ScheduleEmpty = Self(_name="SCHEDULE_EMPTY")
    """Cycles while the uop scheduler is empty."""

    comptime ScheduleUop = Self(_name="SCHEDULE_UOP_ANY")
    """Cycles while the uop scheduler issued at least 1 uop to any execution
    unit."""

    comptime StMemOrderViolLdNonspec = Self(
        _name="ST_MEM_ORDER_VIOL_LD_NONSPEC"
    )
    """Retired core store uops that triggered memory order violations with
    core load uops."""

    comptime StNtUop = Self(_name="ST_NT_UOP")
    """Store uops that executed with non-temporal hint; includes SSVE/SME
    loads because they utilize the Store Unit."""

    comptime StUnitUop = Self(_name="ST_UNIT_UOP")
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
