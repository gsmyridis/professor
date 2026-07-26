from .ffi.attr import (
    PERF_RECORD_MISC_CPUMODE_MASK,
    PERF_RECORD_MISC_CPUMODE_UNKNOWN,
    PERF_RECORD_MISC_KERNEL,
    PERF_RECORD_MISC_USER,
    PERF_RECORD_MISC_HYPERVISOR,
    PERF_RECORD_MISC_GUEST_KERNEL,
    PERF_RECORD_MISC_GUEST_USER,
    PERF_RECORD_MISC_PROC_MAP_PARSE_TIMEOUT,
    PERF_RECORD_MISC_MMAP_DATA,
    PERF_RECORD_MISC_COMM_EXEC,
    PERF_RECORD_MISC_FORK_EXEC,
    PERF_RECORD_MISC_SWITCH_OUT,
    PERF_RECORD_MISC_EXACT_IP,
    PERF_RECORD_MISC_SWITCH_OUT_PREEMPT,
    PERF_RECORD_MISC_MMAP_BUILD_ID,
    PERF_RECORD_MISC_EXT_RESERVED,
)

@fieldwise_init
struct PerfRecordMisc(
    Equatable,
    ImplicitlyCopyable,
    RegisterPassable,
    Writable,
):
    """Additional information from the `misc` field of `perf_event_header`.

    Bits 0 through 2 identify the CPU mode. The remaining values are flags.
    Several flags reuse the same bit because they apply to different record
    types. Interpret those flags together with `perf_event_header.type`.
    """

    var value: UInt16

    # CPU modes. These are mutually exclusive values, not flags.

    comptime CpuModeUnknown = Self(PERF_RECORD_MISC_CPUMODE_UNKNOWN)
    """The CPU mode is unknown."""

    comptime Kernel = Self(PERF_RECORD_MISC_KERNEL)
    """The event occurred in the host kernel."""

    comptime User = Self(PERF_RECORD_MISC_USER)
    """The event occurred in host userspace."""

    comptime Hypervisor = Self(PERF_RECORD_MISC_HYPERVISOR)
    """The event occurred in the hypervisor."""

    comptime GuestKernel = Self(PERF_RECORD_MISC_GUEST_KERNEL)
    """The event occurred in a guest kernel."""

    comptime GuestUser = Self(PERF_RECORD_MISC_GUEST_USER)
    """The event occurred in guest userspace."""

    # Flags. Equal values are intentional: their meaning depends on the
    # record type.

    comptime ProcMapParseTimeout = Self(PERF_RECORD_MISC_PROC_MAP_PARSE_TIMEOUT)
    """Parsing `/proc/PID/maps` timed out, so the mapping data is truncated."""

    comptime MmapData = Self(PERF_RECORD_MISC_MMAP_DATA)
    """An MMAP or MMAP2 record describes a non-executable data mapping."""

    comptime CommExec = Self(PERF_RECORD_MISC_COMM_EXEC)
    """A COMM record reports a process name change caused by `exec`."""

    comptime ForkExec = Self(PERF_RECORD_MISC_FORK_EXEC)
    """A FORK record carries the perf-internal exec marker."""

    comptime SwitchOut = Self(PERF_RECORD_MISC_SWITCH_OUT)
    """A SWITCH record represents a switch away from the current process."""

    comptime ExactIp = Self(PERF_RECORD_MISC_EXACT_IP)
    """A SAMPLE record's IP is the instruction that triggered the event."""

    comptime SwitchOutPreempt = Self(PERF_RECORD_MISC_SWITCH_OUT_PREEMPT)
    """A SWITCH record reports a task preempted in `TASK_RUNNING` state."""

    comptime MmapBuildId = Self(PERF_RECORD_MISC_MMAP_BUILD_ID)
    """An MMAP2 record contains build-ID data instead of device and inode."""

    comptime ExtReserved = Self(PERF_RECORD_MISC_EXT_RESERVED)
    """Reserved by the ABI to indicate an extended `misc` field."""

    @always_inline
    def cpu_mode(self) -> Self:
        """Returns the CPU-mode portion of this value."""
        return Self(self.value & PERF_RECORD_MISC_CPUMODE_MASK)

    @always_inline
    def has_flag(self, flag: Self) -> Bool:
        """Returns whether a non-CPU-mode flag is set.

        CPU-mode values are not flags; compare `cpu_mode()` with the CPU-mode
        aliases instead. A shared flag must be interpreted using the record
        type that accompanies this value.
        """
        return (
            flag.value != 0
            and (flag.value & PERF_RECORD_MISC_CPUMODE_MASK) == 0
            and (self.value & flag.value) == flag.value
        )

    def write_to(self, mut writer: Some[Writer]):
        self.write_repr_to(writer)
