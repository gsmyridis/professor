from .ffi.attr import (
    PERF_FLAG_FD_CLOEXEC,
    PERF_FLAG_FD_NO_GROUP,
    PERF_FLAG_FD_OUTPUT,
    PERF_FLAG_PID_CGROUP,
)

@fieldwise_init
struct Flag(ImplicitlyCopyable, RegisterPassable, Writable):
    """Flags controlling how `perf_event_open` creates an event.

    Flags may be combined by ORing their values. They affect syscall behavior,
    rather than the event measured by `PerfEventAttr`.
    """

    var value: UInt32
    """The raw bit mask passed as the syscall's `flags` argument."""

    comptime NoFlag = Self(0)

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
