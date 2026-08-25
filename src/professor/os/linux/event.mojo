from professor.os.event import Event
from professor.os.linux.sys import (
    PERF_TYPE_HARDWARE,
    PERF_TYPE_SOFTWARE,
    PERF_TYPE_HW_CACHE,
    PERF_COUNT_HW_CPU_CYCLES,
    PERF_COUNT_HW_INSTRUCTIONS,
    PERF_COUNT_HW_CACHE_REFERENCES,
    PERF_COUNT_HW_CACHE_MISSES,
    PERF_COUNT_HW_BRANCH_INSTRUCTIONS,
    PERF_COUNT_HW_BRANCH_MISSES,
    PERF_COUNT_HW_BUS_CYCLES,
    PERF_COUNT_HW_STALLED_CYCLES_FRONTEND,
    PERF_COUNT_HW_STALLED_CYCLES_BACKEND,
    PERF_COUNT_HW_REF_CPU_CYCLES,
    PERF_COUNT_HW_CACHE_L1D,
    PERF_COUNT_HW_CACHE_L1I,
    PERF_COUNT_HW_CACHE_LL,
    PERF_COUNT_HW_CACHE_DTLB,
    PERF_COUNT_HW_CACHE_ITLB,
    PERF_COUNT_HW_CACHE_BPU,
    PERF_COUNT_HW_CACHE_NODE,
    PERF_COUNT_HW_CACHE_OP_READ,
    PERF_COUNT_HW_CACHE_OP_WRITE,
    PERF_COUNT_HW_CACHE_OP_PREFETCH,
    PERF_COUNT_HW_CACHE_RESULT_ACCESS,
    PERF_COUNT_HW_CACHE_RESULT_MISS,
    PERF_COUNT_SW_CPU_CLOCK,
    PERF_COUNT_SW_TASK_CLOCK,
    PERF_COUNT_SW_PAGE_FAULTS,
    PERF_COUNT_SW_CONTEXT_SWITCHES,
    PERF_COUNT_SW_CPU_MIGRATIONS,
    PERF_COUNT_SW_PAGE_FAULTS_MIN,
    PERF_COUNT_SW_PAGE_FAULTS_MAJ,
    PERF_COUNT_SW_ALIGNMENT_FAULTS,
    PERF_COUNT_SW_EMULATION_FAULTS,
    PERF_COUNT_SW_DUMMY,
    PERF_COUNT_SW_BPF_OUTPUT,
    PERF_COUNT_SW_CGROUP_SWITCHES,
    perf_hardware_event_config,
    perf_hardware_cache_config,
)


struct PerfEvent(
    Equatable, Event, ImplicitlyCopyable, RegisterPassable, Writable
):
    """A statically defined Linux perf event.

    An event is identified by the pair (`perf_type()`, `config()`). The name is
    the conventional perf spelling used for display and diagnostics.
    """

    # ===--------------------------------------------------------------------===
    # Fields
    # ===--------------------------------------------------------------------===

    var _name: StaticString
    var _type: UInt32
    var _config: UInt64

    @doc_hidden
    def __init__(
        out self, *, _name: StaticString, _type: UInt32, _config: UInt64
    ):
        self._name = _name
        self._type = _type
        self._config = _config

    # ===--------------------------------------------------------------------===
    # Comptime aliases
    # ===--------------------------------------------------------------------===

    comptime CpuCycles = Self(
        _name="cpu-cycles",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(PERF_COUNT_HW_CPU_CYCLES),
    )
    """Total CPU cycles."""

    comptime Instructions = Self(
        _name="instructions",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(PERF_COUNT_HW_INSTRUCTIONS),
    )
    """Retired instructions."""

    comptime CacheReferences = Self(
        _name="cache-references",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(PERF_COUNT_HW_CACHE_REFERENCES),
    )
    """Cache accesses, usually last-level cache accesses."""

    comptime CacheMisses = Self(
        _name="cache-misses",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(PERF_COUNT_HW_CACHE_MISSES),
    )
    """Cache misses, usually last-level cache misses."""

    comptime BranchInstructions = Self(
        _name="branch-instructions",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(PERF_COUNT_HW_BRANCH_INSTRUCTIONS),
    )
    """Retired branch instructions."""

    comptime BranchMisses = Self(
        _name="branch-misses",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(PERF_COUNT_HW_BRANCH_MISSES),
    )
    """Mispredicted branch instructions."""

    comptime BusCycles = Self(
        _name="bus-cycles",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(PERF_COUNT_HW_BUS_CYCLES),
    )
    """Bus cycles."""

    comptime StalledCyclesFrontend = Self(
        _name="stalled-cycles-frontend",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(
            PERF_COUNT_HW_STALLED_CYCLES_FRONTEND
        ),
    )
    """Cycles stalled during issue."""

    comptime StalledCyclesBackend = Self(
        _name="stalled-cycles-backend",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(
            PERF_COUNT_HW_STALLED_CYCLES_BACKEND
        ),
    )
    """Cycles stalled during retirement."""

    comptime RefCpuCycles = Self(
        _name="ref-cpu-cycles",
        _type=PERF_TYPE_HARDWARE,
        _config=perf_hardware_event_config(PERF_COUNT_HW_REF_CPU_CYCLES),
    )
    """CPU cycles unaffected by frequency scaling."""

    comptime Cycles = Self.CpuCycles
    """Alias for `CpuCycles`."""

    comptime Branches = Self.BranchInstructions
    """Alias for `BranchInstructions`."""

    comptime CpuClock = Self(
        _name="cpu-clock",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_CPU_CLOCK,
    )
    """High-resolution per-CPU clock."""

    comptime TaskClock = Self(
        _name="task-clock",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_TASK_CLOCK,
    )
    """Clock count specific to the running task."""

    comptime PageFaults = Self(
        _name="page-faults",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_PAGE_FAULTS,
    )
    """Page faults."""

    comptime ContextSwitches = Self(
        _name="context-switches",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_CONTEXT_SWITCHES,
    )
    """Context switches."""

    comptime CpuMigrations = Self(
        _name="cpu-migrations",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_CPU_MIGRATIONS,
    )
    """Task migrations between CPUs."""

    comptime MinorPageFaults = Self(
        _name="minor-faults",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_PAGE_FAULTS_MIN,
    )
    """Minor page faults that did not require disk I/O."""

    comptime MajorPageFaults = Self(
        _name="major-faults",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_PAGE_FAULTS_MAJ,
    )
    """Major page faults that required disk I/O."""

    comptime AlignmentFaults = Self(
        _name="alignment-faults",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_ALIGNMENT_FAULTS,
    )
    """Alignment faults handled by the kernel."""

    comptime EmulationFaults = Self(
        _name="emulation-faults",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_EMULATION_FAULTS,
    )
    """Unimplemented instructions emulated by the kernel."""

    comptime Dummy = Self(
        _name="dummy", _type=PERF_TYPE_SOFTWARE, _config=PERF_COUNT_SW_DUMMY
    )
    """Placeholder event that counts nothing."""

    comptime BpfOutput = Self(
        _name="bpf-output",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_BPF_OUTPUT,
    )
    """Raw sample data generated by BPF programs."""

    comptime CgroupSwitches = Self(
        _name="cgroup-switches",
        _type=PERF_TYPE_SOFTWARE,
        _config=PERF_COUNT_SW_CGROUP_SWITCHES,
    )
    """Context switches to a task in a different cgroup."""

    comptime L1DReadAccess = Self(
        _name="L1-dcache-loads",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 data cache read accesses."""

    comptime L1DReadMiss = Self(
        _name="L1-dcache-load-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 data cache read misses."""

    comptime L1DWriteAccess = Self(
        _name="L1-dcache-stores",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 data cache write accesses."""

    comptime L1DWriteMiss = Self(
        _name="L1-dcache-store-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 data cache write misses."""

    comptime L1DPrefetchAccess = Self(
        _name="L1-dcache-prefetches",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 data cache prefetch accesses."""

    comptime L1DPrefetchMiss = Self(
        _name="L1-dcache-prefetch-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 data cache prefetch misses."""

    comptime L1IReadAccess = Self(
        _name="L1-icache-loads",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 instruction cache read accesses."""

    comptime L1IReadMiss = Self(
        _name="L1-icache-load-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 instruction cache read misses."""

    comptime L1IWriteAccess = Self(
        _name="L1-icache-stores",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 instruction cache write accesses."""

    comptime L1IWriteMiss = Self(
        _name="L1-icache-store-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 instruction cache write misses."""

    comptime L1IPrefetchAccess = Self(
        _name="L1-icache-prefetches",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 instruction cache prefetch accesses."""

    comptime L1IPrefetchMiss = Self(
        _name="L1-icache-prefetch-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 instruction cache prefetch misses."""

    comptime LastLevelReadAccess = Self(
        _name="LLC-loads",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Last-level cache read accesses."""

    comptime LastLevelReadMiss = Self(
        _name="LLC-load-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Last-level cache read misses."""

    comptime LastLevelWriteAccess = Self(
        _name="LLC-stores",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Last-level cache write accesses."""

    comptime LastLevelWriteMiss = Self(
        _name="LLC-store-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Last-level cache write misses."""

    comptime LastLevelPrefetchAccess = Self(
        _name="LLC-prefetches",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Last-level cache prefetch accesses."""

    comptime LastLevelPrefetchMiss = Self(
        _name="LLC-prefetch-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Last-level cache prefetch misses."""

    comptime DtlbReadAccess = Self(
        _name="dTLB-loads",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Data TLB read accesses."""

    comptime DtlbReadMiss = Self(
        _name="dTLB-load-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Data TLB read misses."""

    comptime DtlbWriteAccess = Self(
        _name="dTLB-stores",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Data TLB write accesses."""

    comptime DtlbWriteMiss = Self(
        _name="dTLB-store-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Data TLB write misses."""

    comptime DtlbPrefetchAccess = Self(
        _name="dTLB-prefetches",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Data TLB prefetch accesses."""

    comptime DtlbPrefetchMiss = Self(
        _name="dTLB-prefetch-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Data TLB prefetch misses."""

    comptime ItlbReadAccess = Self(
        _name="iTLB-loads",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Instruction TLB read accesses."""

    comptime ItlbReadMiss = Self(
        _name="iTLB-load-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Instruction TLB read misses."""

    comptime ItlbWriteAccess = Self(
        _name="iTLB-stores",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Instruction TLB write accesses."""

    comptime ItlbWriteMiss = Self(
        _name="iTLB-store-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Instruction TLB write misses."""

    comptime ItlbPrefetchAccess = Self(
        _name="iTLB-prefetches",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Instruction TLB prefetch accesses."""

    comptime ItlbPrefetchMiss = Self(
        _name="iTLB-prefetch-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Instruction TLB prefetch misses."""

    comptime BranchReadAccess = Self(
        _name="branch-loads",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Branch prediction unit read accesses."""

    comptime BranchReadMiss = Self(
        _name="branch-load-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Branch prediction unit read misses."""

    comptime BranchWriteAccess = Self(
        _name="branch-stores",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Branch prediction unit write accesses."""

    comptime BranchWriteMiss = Self(
        _name="branch-store-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Branch prediction unit write misses."""

    comptime BranchPrefetchAccess = Self(
        _name="branch-prefetches",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Branch prediction unit prefetch accesses."""

    comptime BranchPrefetchMiss = Self(
        _name="branch-prefetch-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Branch prediction unit prefetch misses."""

    comptime NodeReadAccess = Self(
        _name="node-loads",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """NUMA node read accesses."""

    comptime NodeReadMiss = Self(
        _name="node-load-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """NUMA node read misses."""

    comptime NodeWriteAccess = Self(
        _name="node-stores",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """NUMA node write accesses."""

    comptime NodeWriteMiss = Self(
        _name="node-store-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """NUMA node write misses."""

    comptime NodePrefetchAccess = Self(
        _name="node-prefetches",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """NUMA node prefetch accesses."""

    comptime NodePrefetchMiss = Self(
        _name="node-prefetch-misses",
        _type=PERF_TYPE_HW_CACHE,
        _config=perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """NUMA node prefetch misses."""

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self._name)

    def name(self) -> StaticString:
        """The conventional perf event name, e.g. `"cpu-cycles"`."""
        return self._name

    def type(self) -> UInt32:
        """The `perf_event_attr.type` value."""
        return self._type

    def config(self) -> UInt64:
        """The `perf_event_attr.config` value."""
        return self._config
