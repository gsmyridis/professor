from ._sys import (
    PERF_FLAG_FD_CLOEXEC,
    PERF_FLAG_FD_NO_GROUP,
    PERF_FLAG_FD_OUTPUT,
    PERF_FLAG_PID_CGROUP,
    Attributes,
)


comptime Config = Attributes
"""Perf-Event configuration."""


struct CountMode(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """Execution modes included in an event's count."""

    comptime Userspace = Self(unsafe_mask=UInt8(1))
    comptime Kernel = Self(unsafe_mask=UInt8(2))
    comptime Hypervisor = Self(unsafe_mask=UInt8(4))

    var _mask: UInt8

    def __init__(out self, *, unsafe_mask: UInt8):
        self._mask = unsafe_mask

    def __or__(self, other: Self) -> Self:
        return Self(unsafe_mask=self._mask | other._mask)

    def includes(self, mode: Self) -> Bool:
        return (self._mask & mode._mask) == mode._mask


struct Virtualization(
    Equatable, ImplicitlyCopyable, RegisterPassable, Writable
):
    """Virtualization contexts included in an event's count."""

    comptime Host = Self(unsafe_mask=UInt8(1))
    comptime Guest = Self(unsafe_mask=UInt8(2))

    var _mask: UInt8

    def __init__(out self, *, unsafe_mask: UInt8):
        self._mask = unsafe_mask

    def __or__(self, other: Self) -> Self:
        return Self(unsafe_mask=self._mask | other._mask)

    def includes(self, context: Self) -> Bool:
        return (self._mask & context._mask) == context._mask


@fieldwise_init
struct CpuId(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    var value: UInt32
    """Cpu ID."""

    comptime Any = Self(-1)
    """Any CPU."""


@fieldwise_init
struct ProcessId(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    var value: Int

    comptime All = Self(-1)
    """All processes."""

    comptime Calling = Self(0)
    """Calling process."""


@fieldwise_init
struct Flag(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """Flags controlling how `perf_event_open` creates an event.

    Flags may be combined by ORing their values. They affect syscall behavior,
    rather than the event measured by `PerfEventAttr`.
    """

    var value: UInt32
    """The raw bit mask passed as the syscall's `flags` argument."""

    comptime NoFlag = Self(0)
    """Empty flag."""

    comptime CloseOnExec = Self(PERF_FLAG_FD_CLOEXEC)
    """Close the returned event file descriptor during `execve`.

    The flag is applied atomically when the descriptor is created. This avoids
    the race that can occur when setting `FD_CLOEXEC` later with `fcntl` while
    another thread concurrently calls `fork` followed by `execve`.
    """

    comptime NoGroup = Self(PERF_FLAG_FD_NO_GROUP)
    """Do not use `group_fd` to place this event in an event group.

    When combined with `Output`, `group_fd` is still used as the event whose
    mmap buffer receives this event's sampled output.
    """

    comptime Output = Self(PERF_FLAG_FD_OUTPUT)
    """Redirect sampled output to the mmap buffer belonging to `group_fd`.

    The `perf_event_open(2)` man page documents this facility as broken since
    Linux 2.6.35.
    """

    comptime ContainerGroup = Self(PERF_FLAG_PID_CGROUP)
    """Restrict a system-wide event to tasks in a cgroup.

    With this flag, `pid` must be a file descriptor opened on the cgroup's
    cgroupfs directory, and `cpu` identifies the monitored CPU. Cgroup
    monitoring may require additional permissions.
    """

    def __or__(self, other: Self) -> Self:
        return Self(self.value | other.value)

    def __contains__(self, other: Self) -> Bool:
        return (self.value & other.value) == other.value
