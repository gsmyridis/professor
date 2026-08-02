"""Linux `perf_event_open` constants and ABI types.

The definitions in this module are shared by 64-bit x86 and AArch64 Linux.
Architecture-specific sampled-register definitions are intentionally kept out
of this common layer.
"""

from std.sys import size_of, CompilationTarget
from std.ffi import c_int, c_long, c_size_t, c_ssize_t, c_ulong, external_call

from professor.arch.info import is_aarch64, architecture_map


# ===-----------------------------------------------------------------------===#
# perf_event_attr versions
# ===-----------------------------------------------------------------------===#

comptime PERF_ATTR_SIZE_VER0: UInt32 = 64
comptime PERF_ATTR_SIZE_VER1: UInt32 = 72
comptime PERF_ATTR_SIZE_VER2: UInt32 = 80
comptime PERF_ATTR_SIZE_VER3: UInt32 = 96
comptime PERF_ATTR_SIZE_VER4: UInt32 = 104
comptime PERF_ATTR_SIZE_VER5: UInt32 = 112
comptime PERF_ATTR_SIZE_VER6: UInt32 = 120
comptime PERF_ATTR_SIZE_VER7: UInt32 = 128
comptime PERF_ATTR_SIZE_VER8: UInt32 = 136
comptime PERF_ATTR_SIZE_VER9: UInt32 = 144

# ===-----------------------------------------------------------------------===#
# perf_event_open flags
# ===-----------------------------------------------------------------------===#

comptime PERF_FLAG_FD_NO_GROUP: UInt32 = 1 << 0
comptime PERF_FLAG_FD_OUTPUT: UInt32 = 1 << 1
comptime PERF_FLAG_PID_CGROUP: UInt32 = 1 << 2
comptime PERF_FLAG_FD_CLOEXEC: UInt32 = 1 << 3

# ===-----------------------------------------------------------------------===#
# Event types
# ===-----------------------------------------------------------------------===#

comptime PERF_TYPE_HARDWARE: UInt32 = 0
comptime PERF_TYPE_SOFTWARE: UInt32 = 1
comptime PERF_TYPE_TRACEPOINT: UInt32 = 2
comptime PERF_TYPE_HW_CACHE: UInt32 = 3
comptime PERF_TYPE_RAW: UInt32 = 4
comptime PERF_TYPE_BREAKPOINT: UInt32 = 5
comptime PERF_TYPE_MAX: UInt32 = 6

# ===-----------------------------------------------------------------------===#
# Hardware event configuration
# ===-----------------------------------------------------------------------===#

comptime PERF_PMU_TYPE_SHIFT: UInt64 = 32
comptime PERF_HW_EVENT_MASK: UInt64 = 0xFFFFFFFF


def perf_hardware_event_config(
    event_id: UInt64, *, pmu_type: UInt32 = 0
) -> UInt64:
    """Encode a generic hardware event and optional extended PMU type."""
    return (event_id & PERF_HW_EVENT_MASK) | (
        UInt64(pmu_type) << PERF_PMU_TYPE_SHIFT
    )


def perf_hardware_cache_config(
    cache_id: UInt64,
    operation_id: UInt64,
    result_id: UInt64,
    pmu_type: UInt32 = 0,
) -> UInt64:
    """Encode a `PERF_TYPE_HW_CACHE` event configuration."""
    return (
        cache_id | (operation_id << 8) | (result_id << 16)
    ) & PERF_HW_EVENT_MASK | (UInt64(pmu_type) << PERF_PMU_TYPE_SHIFT)


# ===-----------------------------------------------------------------------===#
# Generic hardware events
# ===-----------------------------------------------------------------------===#

comptime PERF_COUNT_HW_CPU_CYCLES: UInt64 = 0
comptime PERF_COUNT_HW_INSTRUCTIONS: UInt64 = 1
comptime PERF_COUNT_HW_CACHE_REFERENCES: UInt64 = 2
comptime PERF_COUNT_HW_CACHE_MISSES: UInt64 = 3
comptime PERF_COUNT_HW_BRANCH_INSTRUCTIONS: UInt64 = 4
comptime PERF_COUNT_HW_BRANCH_MISSES: UInt64 = 5
comptime PERF_COUNT_HW_BUS_CYCLES: UInt64 = 6
comptime PERF_COUNT_HW_STALLED_CYCLES_FRONTEND: UInt64 = 7
comptime PERF_COUNT_HW_STALLED_CYCLES_BACKEND: UInt64 = 8
comptime PERF_COUNT_HW_REF_CPU_CYCLES: UInt64 = 9
comptime PERF_COUNT_HW_MAX: UInt64 = 10

# ===-----------------------------------------------------------------------===#
# Hardware cache events
# ===-----------------------------------------------------------------------===#

comptime PERF_COUNT_HW_CACHE_L1D: UInt64 = 0
comptime PERF_COUNT_HW_CACHE_L1I: UInt64 = 1
comptime PERF_COUNT_HW_CACHE_LL: UInt64 = 2
comptime PERF_COUNT_HW_CACHE_DTLB: UInt64 = 3
comptime PERF_COUNT_HW_CACHE_ITLB: UInt64 = 4
comptime PERF_COUNT_HW_CACHE_BPU: UInt64 = 5
comptime PERF_COUNT_HW_CACHE_NODE: UInt64 = 6
comptime PERF_COUNT_HW_CACHE_MAX: UInt64 = 7

comptime PERF_COUNT_HW_CACHE_OP_READ: UInt64 = 0
comptime PERF_COUNT_HW_CACHE_OP_WRITE: UInt64 = 1
comptime PERF_COUNT_HW_CACHE_OP_PREFETCH: UInt64 = 2
comptime PERF_COUNT_HW_CACHE_OP_MAX: UInt64 = 3

comptime PERF_COUNT_HW_CACHE_RESULT_ACCESS: UInt64 = 0
comptime PERF_COUNT_HW_CACHE_RESULT_MISS: UInt64 = 1
comptime PERF_COUNT_HW_CACHE_RESULT_MAX: UInt64 = 2

# ===-----------------------------------------------------------------------===#
# Generic software events
# ===-----------------------------------------------------------------------===#

comptime PERF_COUNT_SW_CPU_CLOCK: UInt64 = 0
comptime PERF_COUNT_SW_TASK_CLOCK: UInt64 = 1
comptime PERF_COUNT_SW_PAGE_FAULTS: UInt64 = 2
comptime PERF_COUNT_SW_CONTEXT_SWITCHES: UInt64 = 3
comptime PERF_COUNT_SW_CPU_MIGRATIONS: UInt64 = 4
comptime PERF_COUNT_SW_PAGE_FAULTS_MIN: UInt64 = 5
comptime PERF_COUNT_SW_PAGE_FAULTS_MAJ: UInt64 = 6
comptime PERF_COUNT_SW_ALIGNMENT_FAULTS: UInt64 = 7
comptime PERF_COUNT_SW_EMULATION_FAULTS: UInt64 = 8
comptime PERF_COUNT_SW_DUMMY: UInt64 = 9
comptime PERF_COUNT_SW_BPF_OUTPUT: UInt64 = 10
comptime PERF_COUNT_SW_CGROUP_SWITCHES: UInt64 = 11
comptime PERF_COUNT_SW_MAX: UInt64 = 12

# ===-----------------------------------------------------------------------===#
# Read formats
# ===-----------------------------------------------------------------------===#

comptime PERF_FORMAT_TOTAL_TIME_ENABLED: UInt64 = 1 << 0
comptime PERF_FORMAT_TOTAL_TIME_RUNNING: UInt64 = 1 << 1
comptime PERF_FORMAT_ID: UInt64 = 1 << 2
comptime PERF_FORMAT_GROUP: UInt64 = 1 << 3
comptime PERF_FORMAT_LOST: UInt64 = 1 << 4
comptime PERF_FORMAT_MAX: UInt64 = 1 << 5

# ===-----------------------------------------------------------------------===#
# Misc
# ===-----------------------------------------------------------------------===#

comptime PERF_RECORD_MISC_CPUMODE_MASK: UInt16 = 7
comptime PERF_RECORD_MISC_CPUMODE_UNKNOWN: UInt16 = 0
comptime PERF_RECORD_MISC_KERNEL: UInt16 = 1
comptime PERF_RECORD_MISC_USER: UInt16 = 2
comptime PERF_RECORD_MISC_HYPERVISOR: UInt16 = 3
comptime PERF_RECORD_MISC_GUEST_KERNEL: UInt16 = 4
comptime PERF_RECORD_MISC_GUEST_USER: UInt16 = 5
comptime PERF_RECORD_MISC_PROC_MAP_PARSE_TIMEOUT: UInt16 = 4096
comptime PERF_RECORD_MISC_MMAP_DATA: UInt16 = 8192
comptime PERF_RECORD_MISC_COMM_EXEC: UInt16 = 8192
comptime PERF_RECORD_MISC_FORK_EXEC: UInt16 = 8192
comptime PERF_RECORD_MISC_SWITCH_OUT: UInt16 = 8192
comptime PERF_RECORD_MISC_EXACT_IP: UInt16 = 16384
comptime PERF_RECORD_MISC_SWITCH_OUT_PREEMPT: UInt16 = 16384
comptime PERF_RECORD_MISC_MMAP_BUILD_ID: UInt16 = 16384
comptime PERF_RECORD_MISC_EXT_RESERVED: UInt16 = 32768

# ===-----------------------------------------------------------------------===#
# ioctl functions
# ===-----------------------------------------------------------------------===#

comptime PERF_EVENT_IOC_ENABLE: c_ulong = 9216
comptime PERF_EVENT_IOC_DISABLE: c_ulong = 9217
comptime PERF_EVENT_IOC_REFRESH: c_ulong = 9218
comptime PERF_EVENT_IOC_RESET: c_ulong = 9219
comptime PERF_EVENT_IOC_ID: c_ulong = 2148017159
comptime PERF_IOC_FLAG_GROUP: c_ulong = 1

comptime PERF_EVENT_OPEN_SYSCALL = architecture_map[
    T=c_long, "PERF_EVENT_OPEN_SYSCALL", x86=c_long(298), aarch64=c_long(241)
]

# ===-----------------------------------------------------------------------===#
# perf_event_attr
# ===-----------------------------------------------------------------------===#


struct Attributes(Copyable, Defaultable):
    """ABI-compatible Linux `struct perf_event_attr`.

    Anonymous C unions are represented by one storage field each. For example,
    `sample_period_or_freq` contains either `sample_period` or `sample_freq`,
    depending on the `freq` flag.
    """

    var type_: UInt32
    var size: UInt32
    var config: UInt64
    var sample_period_or_freq: UInt64
    var sample_type: UInt64
    var read_format: UInt64
    var flags: UInt64
    var wakeup_events_or_watermark: UInt32
    var bp_type: UInt32
    var config1: UInt64
    var config2: UInt64
    var branch_sample_type: UInt64
    var sample_regs_user: UInt64
    var sample_stack_user: UInt32
    var clockid: Int32
    var sample_regs_intr: UInt64
    var aux_watermark: UInt32
    var sample_max_stack: UInt16
    var reserved_2: UInt16
    var aux_sample_size: UInt32
    var aux_action: UInt32
    var sig_data: UInt64
    var config3: UInt64
    var config4: UInt64

    def __init__(out self):
        self.type_ = 0
        self.size = UInt32(size_of[Self]())
        self.config = 0
        self.sample_period_or_freq = 0
        self.sample_type = 0
        self.read_format = 0
        self.flags = 0
        self.wakeup_events_or_watermark = 0
        self.bp_type = 0
        self.config1 = 0
        self.config2 = 0
        self.branch_sample_type = 0
        self.sample_regs_user = 0
        self.sample_stack_user = 0
        self.clockid = 0
        self.sample_regs_intr = 0
        self.aux_watermark = 0
        self.sample_max_stack = 0
        self.reserved_2 = 0
        self.aux_sample_size = 0
        self.aux_action = 0
        self.sig_data = 0
        self.config3 = 0
        self.config4 = 0

    @always_inline
    def _set_flag(mut self, bit: Int, enabled: Bool):
        var mask = UInt64(1) << UInt64(bit)
        if enabled:
            self.flags |= mask
        else:
            self.flags &= ~mask

    @always_inline
    def _get_flag(self, bit: Int) -> Bool:
        return Bool(self.flags & (UInt64(1) << UInt64(bit)))

    def set_disabled(mut self, enabled: Bool = True):
        self._set_flag(0, enabled)

    def disabled(self) -> Bool:
        return self._get_flag(0)

    def set_inherit(mut self, enabled: Bool = True):
        self._set_flag(1, enabled)

    def inherit(self) -> Bool:
        return self._get_flag(1)

    def set_pinned(mut self, enabled: Bool = True):
        self._set_flag(2, enabled)

    def pinned(self) -> Bool:
        return self._get_flag(2)

    def set_exclusive(mut self, enabled: Bool = True):
        self._set_flag(3, enabled)

    def exclusive(self) -> Bool:
        return self._get_flag(3)

    def set_exclude_user(mut self, enabled: Bool = True):
        self._set_flag(4, enabled)

    def exclude_user(self) -> Bool:
        return self._get_flag(4)

    def set_exclude_kernel(mut self, enabled: Bool = True):
        self._set_flag(5, enabled)

    def exclude_kernel(self) -> Bool:
        return self._get_flag(5)

    def set_exclude_hv(mut self, enabled: Bool = True):
        self._set_flag(6, enabled)

    def exclude_hv(self) -> Bool:
        return self._get_flag(6)

    def set_exclude_idle(mut self, enabled: Bool = True):
        self._set_flag(7, enabled)

    def exclude_idle(self) -> Bool:
        return self._get_flag(7)

    def set_freq(mut self, enabled: Bool = True):
        self._set_flag(10, enabled)

    def freq(self) -> Bool:
        return self._get_flag(10)

    def set_inherit_stat(mut self, enabled: Bool = True):
        self._set_flag(11, enabled)

    def inherit_stat(self) -> Bool:
        return self._get_flag(11)

    def set_enable_on_exec(mut self, enabled: Bool = True):
        self._set_flag(12, enabled)

    def enable_on_exec(self) -> Bool:
        return self._get_flag(12)

    def set_exclude_host(mut self, enabled: Bool = True):
        self._set_flag(19, enabled)

    def exclude_host(self) -> Bool:
        return self._get_flag(19)

    def set_exclude_guest(mut self, enabled: Bool = True):
        self._set_flag(20, enabled)

    def exclude_guest(self) -> Bool:
        return self._get_flag(20)

    def set_inherit_thread(mut self, enabled: Bool = True):
        self._set_flag(35, enabled)

    def inherit_thread(self) -> Bool:
        return self._get_flag(35)

    def set_remove_on_exec(mut self, enabled: Bool = True):
        self._set_flag(36, enabled)

    def remove_on_exec(self) -> Bool:
        return self._get_flag(36)


# ===-----------------------------------------------------------------------===#
# perf functions
# ===-----------------------------------------------------------------------===#


@always_inline
def perf_event_open[
    origin: MutOrigin,
](
    attrs: UnsafePointer[Attributes, origin],
    pid: c_int,
    cpu: c_int,
    group_fd: c_int,
    flags: c_ulong,
) -> c_int:
    """Open a Linux performance-monitoring event.

    Each successful call creates one event file descriptor. Pass `-1` as
    `group_fd` to create a standalone event or group leader. Pass a leader's
    file descriptor to add a member that is scheduled with the rest of that
    group.

    Args:
        attrs: Pointer to an initialized `Attributes` describing the event
                and its counting behavior.
        pid: Thread selection. `0` selects the calling thread, a positive value
            selects that thread ID, and `-1` selects all threads. With
            `PERF_FLAG_PID_CGROUP`, this is instead a cgroup file descriptor.
        cpu: CPU selection. `-1` follows the selected thread on any CPU; a
            nonnegative value restricts measurement to that logical CPU.
            `pid == -1` requires a nonnegative CPU.
        group_fd: `-1` for a standalone event or new group leader, otherwise
            the file descriptor of the group leader to join.
        flags: Bitwise combination of `PERF_FLAG_*` syscall flags.

    Returns:
        A nonnegative event file descriptor on success, or `-1` on failure with
        `errno` set by the kernel.
    """
    comptime assert (
        CompilationTarget.is_linux()
    ), "perf event open is only available on Linux"

    return c_int(
        external_call["syscall", c_long](
            PERF_EVENT_OPEN_SYSCALL,
            attrs,
            c_long(pid),
            c_long(cpu),
            c_long(group_fd),
            flags,
        )
    )


@always_inline
def _perf_event_ioctl(fd: c_int, request: c_ulong, arg: c_ulong) -> c_int:
    """Invoke a perf event ioctl with a machine-word argument.

    Args:
        fd: File descriptor returned by `perf_event_open`.
        request: A `PERF_EVENT_IOC_*` request code.
        arg: Request-specific scalar, flag mask, or pointer address.

    Returns:
        The ioctl result, normally `0` on success or `-1` on failure with
        `errno` set.
    """
    comptime assert (
        CompilationTarget.is_linux()
    ), "perf event ioctls are only available on Linux"
    return external_call["ioctl", c_int](fd, request, arg)


def perf_event_enable(fd: c_int, flags: c_ulong = 0) -> c_int:
    """Enable counting for an event or event group.

    Enabling a group leader enables its group. Passing `PERF_IOC_FLAG_GROUP`
    applies the operation to the entire group even when `fd` refers to a member.

    Args:
        fd: File descriptor of the event or group to enable.
        flags: `0` for normal leader/member behavior, or `PERF_IOC_FLAG_GROUP`
                to target the entire group.

    Returns:
        `0` on success, or `-1` on failure with `errno` set.
    """
    return _perf_event_ioctl(fd, PERF_EVENT_IOC_ENABLE, flags)


def perf_event_disable(fd: c_int, flags: c_ulong = 0) -> c_int:
    """Disable counting for an event or event group.

    Disabling a group leader disables its group. Disabling a member affects
    only that member unless `PERF_IOC_FLAG_GROUP` is passed.

    Args:
        fd: File descriptor of the event or group to disable.
        flags: `0` for normal leader/member behavior, or `PERF_IOC_FLAG_GROUP`
                to target the entire group.

    Returns:
        `0` on success, or `-1` on failure with `errno` set.
    """
    return _perf_event_ioctl(fd, PERF_EVENT_IOC_DISABLE, flags)


def perf_event_refresh(fd: c_int, count: c_ulong) -> c_int:
    """Enable a non-inherited sampling event for additional overflows.

    Each call adds `count` to the number of overflows allowed before the event
    is disabled. Passing `0` has undefined behavior according to the Linux perf
    event ABI.

    Args:
        fd: File descriptor of a non-inherited overflow event.
        count: Positive number of additional overflows to allow.

    Returns:
        `0` on success, or `-1` on failure with `errno` set.
    """
    return _perf_event_ioctl(fd, PERF_EVENT_IOC_REFRESH, count)


def perf_event_reset(fd: c_int, flags: c_ulong = 0) -> c_int:
    """Reset event counts to zero without resetting multiplexing times.

    Args:
        fd: File descriptor of the event or group to reset.
        flags: `0` to reset the selected event, or `PERF_IOC_FLAG_GROUP` to
                reset every event in its group.

    Returns:
        `0` on success, or `-1` on failure with `errno` set.
    """
    return _perf_event_ioctl(fd, PERF_EVENT_IOC_RESET, flags)


def perf_event_id[
    origin: MutOrigin,
](fd: c_int, id_out: UnsafePointer[UInt64, origin]) -> c_int:
    """Read an event's kernel-assigned identifier.

    The identifier can be used to associate entries returned by a
    `PERF_FORMAT_GROUP | PERF_FORMAT_ID` read with their event descriptors.

    Args:
        fd: File descriptor of the event whose identifier is requested.
        id_out: Writable pointer that receives the 64-bit event identifier.

    Returns:
        `0` on success, or `-1` on failure with `errno` set.
    """
    return _perf_event_ioctl(fd, PERF_EVENT_IOC_ID, c_ulong(Int(id_out)))


def perf_event_read[
    origin: MutOrigin,
](
    fd: c_int,
    values: UnsafePointer[UInt64, origin],
    value_capacity: c_size_t,
) -> c_ssize_t:
    """Read a counting payload from an event file descriptor.

    The payload is a sequence of 64-bit words whose layout is selected by the
    event's `PerfEventAttr.read_format`. Group reads require enough capacity
    for the group header and every member; Linux returns `ENOSPC` instead of a
    truncated group result when the buffer is too small.

    Args:
        fd: File descriptor of the event or group leader to read.
        values: Writable pointer to the first 64-bit word of the result buffer.
        value_capacity: Capacity of `values`, measured in 64-bit words.

    Returns:
        The number of bytes written on success, or `-1` on failure with
        `errno` set.
    """
    comptime assert (
        CompilationTarget.is_linux()
    ), "perf event reads are only available on Linux"
    return external_call["read", c_ssize_t](
        fd,
        values,
        value_capacity * c_size_t(size_of[UInt64]()),
    )
