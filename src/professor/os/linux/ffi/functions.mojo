"""Raw Linux `perf_event_open`, `ioctl`, and `read` wrappers."""

from std.ffi import c_int, c_long, c_size_t, c_ssize_t, c_ulong, external_call
from std.sys import CompilationTarget, size_of

from .attr import PerfEventAttr

# ===-----------------------------------------------------------------------===#
# ioctl functions
# ===-----------------------------------------------------------------------===#

comptime PERF_EVENT_IOC_ENABLE: c_ulong = 9216
comptime PERF_EVENT_IOC_DISABLE: c_ulong = 9217
comptime PERF_EVENT_IOC_REFRESH: c_ulong = 9218
comptime PERF_EVENT_IOC_RESET: c_ulong = 9219
comptime PERF_EVENT_IOC_ID: c_ulong = 2148017159
comptime PERF_IOC_FLAG_GROUP: c_ulong = 1


@always_inline
def _perf_event_open_syscall_number() -> c_long:
    """Return the `perf_event_open` syscall number for the target architecture.

    Returns:
        `241` on AArch64 Linux or `298` on x86-64 Linux.
    """
    comptime assert (
        CompilationTarget.is_linux()
    ), "perf_event_open is only available on Linux"
    # AArch64 requires Advanced SIMD, while x86-64 requires SSE2.
    comptime if CompilationTarget.has_neon():
        return 241
    elif CompilationTarget._has_feature["sse2"]():
        return 298
    else:
        CompilationTarget.unsupported_target_error[
            operation="perf_event_open",
            note="only x86_64 and AArch64 Linux are currently supported",
        ]()


@always_inline
def perf_event_open[
    origin: MutOrigin,
](
    attrs: UnsafePointer[PerfEventAttr, origin],
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
        attrs: Pointer to an initialized `PerfEventAttr` describing the event
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
    return c_int(
        external_call["syscall", c_long](
            _perf_event_open_syscall_number(),
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
