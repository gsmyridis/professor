from .ffi import kperf as ffi_kperf
from .ffi.kperf import KPCConfig
from std.ffi import c_char, c_int, c_size_t


# TODO: classes should be a compbination of enum-like structs
@always_inline
def set_thread_counting(classes: UInt32) raises:
    """Sets PMC classes to enable counting for the current thread.

    `classes` is a combination of `KPC_CLASS_*_MASK` constants; pass 0
    to shut down counting.

    Raises:
        When it fails to set the counting.
    """
    if ffi_kperf.kpc_set_thread_counting(classes) != 0:
        raise Error("failed to set")


# TODO: Make MASKS enum-like structs, maybe return an inline array
# or struct that gives the information.
@always_inline
def get_thread_counting() -> UInt32:
    """Gets running PMC classes for the current thread.

    Returns:
        A combination of `KPC_CLASS_*_MASK` constants, or 0 if an error
        occurs or no class is set.
    """
    return ffi_kperf.kpc_get_thread_counting()


@always_inline
def set_counting(classes: UInt32) raises:
    """Sets PMC classes to enable global counting."""
    if ffi_kperf.kpc_set_counting(classes) != 0:
        raise Error("failed to set global counting")


@always_inline
def get_counting() -> UInt32:
    """Gets running PMC classes."""
    return ffi_kperf.kpc_get_counting()


@always_inline
def get_config_count(classes: UInt32) -> UInt32:
    """Gets the number of config registers for a class mask.

    For example, Intel may return 1 for `KPC_CLASS_FIXED_MASK` and 4 for
    `KPC_CLASS_CONFIGURABLE_MASK`.

    This function does not require root privileges.

    Args:
        classes: A combination of `KPC_CLASS_*_MASK` constants.

    Returns:
        The number of config registers, or 0 if an error occurs or no class
        is set.
    """
    return ffi_kperf.kpc_get_config_count(classes)


@always_inline
def get_counter_count(classes: UInt32) -> UInt32:
    """Gets the number of counters for a class mask.

    For example, Intel may return 3 for `KPC_CLASS_FIXED_MASK` and 4 for
    `KPC_CLASS_CONFIGURABLE_MASK`.

    This function does not require root privileges.

    Args:
        classes: A combination of `KPC_CLASS_*_MASK` constants.
    """
    return ffi_kperf.kpc_get_counter_count(classes)


@always_inline
def set_config(classes: UInt32, mut config: List[KPCConfig]) raises:
    """Sets config registers.

    `config` should contain at least `get_config_count(classes)` elements.

    Args:
        classes: A combination of `KPC_CLASS_*_MASK` constants.
        config: Buffer containing the config register values.
    """
    if ffi_kperf.kpc_set_config(classes, config.unsafe_ptr()) != 0:
        raise Error("failed to set config")


@always_inline
def get_config(classes: UInt32, mut config: List[KPCConfig]) raises:
    """Gets config registers.

    `config` should have room for at least `get_config_count(classes)`
    elements.

    Args:
        classes: A combination of `KPC_CLASS_*_MASK` constants.
        config: Buffer to receive the config register values.
    """
    if ffi_kperf.kpc_get_config(classes, config.unsafe_ptr()) != 0:
        raise Error("failed to get config")


@always_inline
def get_cpu_counters(
    all_cpus: Bool,
    classes: UInt32,
    curcpu: OptionalUnsafePointer[c_int, MutUntrackedOrigin],
    buf: UnsafePointer[UInt64, MutUntrackedOrigin],
) raises:
    """Gets counter accumulations.

    If `all_cpus` is true, `buf` should contain at least
    `cpu_count * counter_count` elements. Otherwise, it should contain at
    least `counter_count` elements.

    Args:
        all_cpus: True for all CPUs; false for the current CPU.
        classes: A combination of `KPC_CLASS_*_MASK` constants.
        curcpu: Pointer to receive the current CPU id; may be null.
        buf: Buffer to receive counter values.
    """
    if ffi_kperf.kpc_get_cpu_counters(all_cpus, classes, curcpu, buf) != 0:
        raise Error("failed to get cpu counters")


@always_inline
def get_thread_counters[
    origin: MutOrigin, //
](tid: UInt32, buf_count: UInt32, buf: UnsafePointer[UInt64, origin],) raises:
    """Gets counter accumulations for the current thread.

    Args:
        tid: Thread id; should be 0.
        buf_count: Number of elements in `buf`, not bytes; should be at
            least `get_counter_count(classes)`.
        buf: Buffer to receive counter values.
    """
    if ffi_kperf.kpc_get_thread_counters(tid, buf_count, buf) != 0:
        raise Error("failed to get thread counters")


@always_inline
def force_all_ctrs_set(val: c_int) raises:
    """Acquires or releases counters used by the Power Manager.

    Args:
        val: 1 to acquire; 0 to release.
    """
    if ffi_kperf.kpc_force_all_ctrs_set(val) != 0:
        raise Error(t"failed to set force_all_ctrs to {val}")


@always_inline
def force_all_ctrs_get() raises -> c_int:
    """Gets the state of `force_all_ctrs`.

    Returns:
        The current state.
    """
    var val: c_int = 0
    var res = ffi_kperf.kpc_force_all_ctrs_get(UnsafePointer(to=val))
    if res != 0:
        raise Error("failed to get force_all_ctrs state")

    return val


@always_inline
def kperf_action_count_set(count: UInt32) raises:
    """Sets the number of actions. The maximum is `KPERF_ACTION_MAX`.

    Args:
        count: Number of actions.
    """
    if ffi_kperf.kperf_action_count_set(count) != 0:
        raise Error(t"failed to set action count to {count}")


@always_inline
def kperf_action_count_get() raises -> UInt32:
    """Gets the number of actions.

    Returns:
        The number of actions.
    """
    var count: UInt32 = 0
    var res = ffi_kperf.kperf_action_count_get(UnsafePointer(to=count))
    if res != 0:
        raise Error("failed to get action count")

    return count


@always_inline
def kperf_action_samplers_set(actionid: UInt32, sample: UInt32) raises:
    """Sets what an action samples when its trigger fires.

    The sample mask may include values such as `KPERF_SAMPLER_PMC_CPU`.

    Args:
        actionid: Action id.
        sample: Combination of `KPERF_SAMPLER_*` constants.
    """
    if ffi_kperf.kperf_action_samplers_set(actionid, sample) != 0:
        raise Error(t"failed to set samplers for action {actionid}")


@always_inline
def kperf_action_samplers_get(actionid: UInt32) raises -> UInt32:
    """Gets what an action samples when its trigger fires.

    Args:
        actionid: Action id.

    Returns:
        Combination of `KPERF_SAMPLER_*` constants.
    """
    var sample: UInt32 = 0
    var res = ffi_kperf.kperf_action_samplers_get(
        actionid, UnsafePointer(to=sample)
    )
    if res != 0:
        raise Error(t"failed to get samplers for action {actionid}")

    return sample


@always_inline
def kperf_action_filter_set_by_task(actionid: UInt32, port: Int32) raises:
    """Applies a task filter to an action. Pass -1 to disable the filter.

    Args:
        actionid: Action id.
        port: Task port, or -1 to disable the filter.
    """
    if ffi_kperf.kperf_action_filter_set_by_task(actionid, port) != 0:
        raise Error(t"failed to set task filter for action {actionid}")


@always_inline
def kperf_action_filter_set_by_pid(actionid: UInt32, pid: Int32) raises:
    """Applies a pid filter to an action. Pass -1 to disable the filter.

    Args:
        actionid: Action id.
        pid: Process id, or -1 to disable the filter.
    """
    if ffi_kperf.kperf_action_filter_set_by_pid(actionid, pid) != 0:
        raise Error(t"failed to set pid filter for action {actionid}")


@always_inline
def kperf_timer_count_set(count: UInt32) raises:
    """Sets the number of timer triggers. The maximum is `KPERF_TIMER_MAX`.

    Args:
        count: Number of timer triggers.
    """
    if ffi_kperf.kperf_timer_count_set(count) != 0:
        raise Error(t"failed to set timer count to {count}")


@always_inline
def kperf_timer_count_get() raises -> UInt32:
    """Gets the number of timer triggers.

    Returns:
        Pointer to receive the number of timer triggers.
    """
    var count: UInt32 = 0
    var res = ffi_kperf.kperf_timer_count_get(UnsafePointer(to=count))
    if res != 0:
        raise Error("failed to get timer count")

    return count


@always_inline
def kperf_timer_period_set(timer_id: UInt32, period: UInt64) raises:
    """Sets a timer period."""
    if ffi_kperf.kperf_timer_period_set(timer_id, period) != 0:
        raise Error(t"failed to set {period} for timer {timer_id}")


@always_inline
def kperf_timer_period_get(timer_id: UInt32) raises -> UInt64:
    """Gets a timer period."""
    var period: UInt64 = 0
    var res = ffi_kperf.kperf_timer_period_get(
        timer_id, UnsafePointer(to=period)
    )
    if res != 0:
        raise Error(t"failed to get timer {timer_id} period")
    return period


@always_inline
def kperf_timer_action_set(timerid: UInt32, actionid: UInt32) raises:
    """Sets the action id associated with a timer."""
    if ffi_kperf.kperf_timer_action_set(timerid, actionid) != 0:
        raise Error(t"failed to set action {actionid} for timer {timerid}")


@always_inline
def kperf_timer_action_get(timer_id: UInt32) raises -> UInt32:
    """Gets the action id associated with a timer.

    Returns:
        The action id associated with the timer.
    """
    var action_id: UInt32 = 0
    var res = ffi_kperf.kperf_timer_action_get(
        timer_id, UnsafePointer(to=action_id)
    )
    if res != 0:
        raise Error("failed to get action id")

    return action_id


@always_inline
def kperf_sample_set(enabled: UInt32) raises:
    """Enables or disables sampling.

    Writes `kperf.sampling` via `sysctl`.

    Args:
        enabled: Non-zero to enable sampling; 0 to disable it.
    """
    if ffi_kperf.kperf_sample_set(enabled) != 0:
        raise Error("failed to set the sampling state")


@always_inline
def kperf_sample_get() raises -> UInt32:
    """Gets whether sampling is active.

    Returns:
        The sampling state.
    """
    var state: UInt32 = 0
    var res = ffi_kperf.kperf_sample_get(UnsafePointer(to=state))
    if res != 0:
        raise Error("failed to get the sampling state")

    return state


@always_inline
def kperf_reset() raises:
    """Resets kperf: stops sampling, kdebug, timers, and actions."""
    if ffi_kperf.kperf_reset() != 0:
        raise Error("failed to reset kperf")


@always_inline
def kperf_timer_pet_set(timerid: UInt32) raises:
    """Sets which timer id that performs PET (Profile Every Thread).

    Writes `kperf.timer.pet_timer` via `sysctl`.

    Args:
        timerid: Timer id.
    """
    if ffi_kperf.kperf_timer_pet_set(timerid) != 0:
        raise Error(t"failed to set PET timer with timer ID: {timerid}")


@always_inline
def kperf_timer_pet_get() raises -> UInt32:
    """Gets which timer ID that performs PET (Profile Every Thread).

    Returns:
        The timer ID.
    """
    var timer_id: UInt32 = 0
    var res = ffi_kperf.kperf_timer_pet_get(UnsafePointer(to=timer_id))
    if res != 0:
        raise Error("failed to read the PET timer ID")

    return timer_id


@always_inline
def kperf_ns_to_ticks(ns: UInt64) -> UInt64:
    """Converts nanoseconds to CPU ticks."""
    return ffi_kperf.kperf_ns_to_ticks(ns)


@always_inline
def kperf_ticks_to_ns(ticks: UInt64) -> UInt64:
    """Converts CPU ticks to nanoseconds."""
    return ffi_kperf.kperf_ticks_to_ns(ticks)


@always_inline
def kperf_tick_frequency() -> UInt64:
    """Gets the CPU tick frequency used by `mach_absolute_time`."""
    return ffi_kperf.kperf_tick_frequency()
