from professor.os.event import Event
from professor.os.linux._sys import (
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


@fieldwise_init
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

    # ===--------------------------------------------------------------------===
    # Comptime aliases
    # ===--------------------------------------------------------------------===

    comptime CpuCycles = Self(
        "cpu-cycles",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_CPU_CYCLES),
    )
    """Total CPU cycles."""

    comptime Instructions = Self(
        "instructions",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_INSTRUCTIONS),
    )
    """Retired instructions."""

    comptime CacheReferences = Self(
        "cache-references",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_CACHE_REFERENCES),
    )
    """Cache accesses, usually last-level cache accesses."""

    comptime CacheMisses = Self(
        "cache-misses",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_CACHE_MISSES),
    )
    """Cache misses, usually last-level cache misses."""

    comptime BranchInstructions = Self(
        "branch-instructions",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_BRANCH_INSTRUCTIONS),
    )
    """Retired branch instructions."""

    comptime BranchMisses = Self(
        "branch-misses",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_BRANCH_MISSES),
    )
    """Mispredicted branch instructions."""

    comptime BusCycles = Self(
        "bus-cycles",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_BUS_CYCLES),
    )
    """Bus cycles."""

    comptime StalledCyclesFrontend = Self(
        "stalled-cycles-frontend",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_STALLED_CYCLES_FRONTEND),
    )
    """Cycles stalled during issue."""

    comptime StalledCyclesBackend = Self(
        "stalled-cycles-backend",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_STALLED_CYCLES_BACKEND),
    )
    """Cycles stalled during retirement."""

    comptime RefCpuCycles = Self(
        "ref-cpu-cycles",
        PERF_TYPE_HARDWARE,
        perf_hardware_event_config(PERF_COUNT_HW_REF_CPU_CYCLES),
    )
    """CPU cycles unaffected by frequency scaling."""

    comptime Cycles = Self.CpuCycles
    """Alias for `CpuCycles`."""

    comptime Branches = Self.BranchInstructions
    """Alias for `BranchInstructions`."""

    comptime CpuClock = Self(
        "cpu-clock", PERF_TYPE_SOFTWARE, PERF_COUNT_SW_CPU_CLOCK
    )
    """High-resolution per-CPU clock."""

    comptime TaskClock = Self(
        "task-clock", PERF_TYPE_SOFTWARE, PERF_COUNT_SW_TASK_CLOCK
    )
    """Clock count specific to the running task."""

    comptime PageFaults = Self(
        "page-faults", PERF_TYPE_SOFTWARE, PERF_COUNT_SW_PAGE_FAULTS
    )
    """Page faults."""

    comptime ContextSwitches = Self(
        "context-switches",
        PERF_TYPE_SOFTWARE,
        PERF_COUNT_SW_CONTEXT_SWITCHES,
    )
    """Context switches."""

    comptime CpuMigrations = Self(
        "cpu-migrations", PERF_TYPE_SOFTWARE, PERF_COUNT_SW_CPU_MIGRATIONS
    )
    """Task migrations between CPUs."""

    comptime MinorPageFaults = Self(
        "minor-faults", PERF_TYPE_SOFTWARE, PERF_COUNT_SW_PAGE_FAULTS_MIN
    )
    """Minor page faults that did not require disk I/O."""

    comptime MajorPageFaults = Self(
        "major-faults", PERF_TYPE_SOFTWARE, PERF_COUNT_SW_PAGE_FAULTS_MAJ
    )
    """Major page faults that required disk I/O."""

    comptime AlignmentFaults = Self(
        "alignment-faults",
        PERF_TYPE_SOFTWARE,
        PERF_COUNT_SW_ALIGNMENT_FAULTS,
    )
    """Alignment faults handled by the kernel."""

    comptime EmulationFaults = Self(
        "emulation-faults",
        PERF_TYPE_SOFTWARE,
        PERF_COUNT_SW_EMULATION_FAULTS,
    )
    """Unimplemented instructions emulated by the kernel."""

    comptime Dummy = Self("dummy", PERF_TYPE_SOFTWARE, PERF_COUNT_SW_DUMMY)
    """Placeholder event that counts nothing."""

    comptime BpfOutput = Self(
        "bpf-output", PERF_TYPE_SOFTWARE, PERF_COUNT_SW_BPF_OUTPUT
    )
    """Raw sample data generated by BPF programs."""

    comptime CgroupSwitches = Self(
        "cgroup-switches",
        PERF_TYPE_SOFTWARE,
        PERF_COUNT_SW_CGROUP_SWITCHES,
    )
    """Context switches to a task in a different cgroup."""

    comptime L1DReadAccess = Self(
        "L1-dcache-loads",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 data cache read accesses."""

    comptime L1DReadMiss = Self(
        "L1-dcache-load-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 data cache read misses."""

    comptime L1DWriteAccess = Self(
        "L1-dcache-stores",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 data cache write accesses."""

    comptime L1DWriteMiss = Self(
        "L1-dcache-store-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 data cache write misses."""

    comptime L1DPrefetchAccess = Self(
        "L1-dcache-prefetches",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 data cache prefetch accesses."""

    comptime L1DPrefetchMiss = Self(
        "L1-dcache-prefetch-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1D,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 data cache prefetch misses."""

    comptime L1IReadAccess = Self(
        "L1-icache-loads",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 instruction cache read accesses."""

    comptime L1IReadMiss = Self(
        "L1-icache-load-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 instruction cache read misses."""

    comptime L1IWriteAccess = Self(
        "L1-icache-stores",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 instruction cache write accesses."""

    comptime L1IWriteMiss = Self(
        "L1-icache-store-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 instruction cache write misses."""

    comptime L1IPrefetchAccess = Self(
        "L1-icache-prefetches",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Level 1 instruction cache prefetch accesses."""

    comptime L1IPrefetchMiss = Self(
        "L1-icache-prefetch-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_L1I,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Level 1 instruction cache prefetch misses."""

    comptime LastLevelReadAccess = Self(
        "LLC-loads",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Last-level cache read accesses."""

    comptime LastLevelReadMiss = Self(
        "LLC-load-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Last-level cache read misses."""

    comptime LastLevelWriteAccess = Self(
        "LLC-stores",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Last-level cache write accesses."""

    comptime LastLevelWriteMiss = Self(
        "LLC-store-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Last-level cache write misses."""

    comptime LastLevelPrefetchAccess = Self(
        "LLC-prefetches",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Last-level cache prefetch accesses."""

    comptime LastLevelPrefetchMiss = Self(
        "LLC-prefetch-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_LL,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Last-level cache prefetch misses."""

    comptime DtlbReadAccess = Self(
        "dTLB-loads",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Data TLB read accesses."""

    comptime DtlbReadMiss = Self(
        "dTLB-load-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Data TLB read misses."""

    comptime DtlbWriteAccess = Self(
        "dTLB-stores",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Data TLB write accesses."""

    comptime DtlbWriteMiss = Self(
        "dTLB-store-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Data TLB write misses."""

    comptime DtlbPrefetchAccess = Self(
        "dTLB-prefetches",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Data TLB prefetch accesses."""

    comptime DtlbPrefetchMiss = Self(
        "dTLB-prefetch-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_DTLB,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Data TLB prefetch misses."""

    comptime ItlbReadAccess = Self(
        "iTLB-loads",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Instruction TLB read accesses."""

    comptime ItlbReadMiss = Self(
        "iTLB-load-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Instruction TLB read misses."""

    comptime ItlbWriteAccess = Self(
        "iTLB-stores",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Instruction TLB write accesses."""

    comptime ItlbWriteMiss = Self(
        "iTLB-store-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Instruction TLB write misses."""

    comptime ItlbPrefetchAccess = Self(
        "iTLB-prefetches",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Instruction TLB prefetch accesses."""

    comptime ItlbPrefetchMiss = Self(
        "iTLB-prefetch-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_ITLB,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Instruction TLB prefetch misses."""

    comptime BranchReadAccess = Self(
        "branch-loads",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Branch prediction unit read accesses."""

    comptime BranchReadMiss = Self(
        "branch-load-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Branch prediction unit read misses."""

    comptime BranchWriteAccess = Self(
        "branch-stores",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Branch prediction unit write accesses."""

    comptime BranchWriteMiss = Self(
        "branch-store-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Branch prediction unit write misses."""

    comptime BranchPrefetchAccess = Self(
        "branch-prefetches",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """Branch prediction unit prefetch accesses."""

    comptime BranchPrefetchMiss = Self(
        "branch-prefetch-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_BPU,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """Branch prediction unit prefetch misses."""

    comptime NodeReadAccess = Self(
        "node-loads",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """NUMA node read accesses."""

    comptime NodeReadMiss = Self(
        "node-load-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_READ,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """NUMA node read misses."""

    comptime NodeWriteAccess = Self(
        "node-stores",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """NUMA node write accesses."""

    comptime NodeWriteMiss = Self(
        "node-store-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_WRITE,
            PERF_COUNT_HW_CACHE_RESULT_MISS,
        ),
    )
    """NUMA node write misses."""

    comptime NodePrefetchAccess = Self(
        "node-prefetches",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
            PERF_COUNT_HW_CACHE_NODE,
            PERF_COUNT_HW_CACHE_OP_PREFETCH,
            PERF_COUNT_HW_CACHE_RESULT_ACCESS,
        ),
    )
    """NUMA node prefetch accesses."""

    comptime NodePrefetchMiss = Self(
        "node-prefetch-misses",
        PERF_TYPE_HW_CACHE,
        perf_hardware_cache_config(
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
