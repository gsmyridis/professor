"""Structs, error codes and function pointer aliases for `kperf.framework`.

This module covers two subsystems that live inside the same framework:

- **KPC** (Kernel Performance Counters): configuring which counter classes
are active ([`kpc_set_counting`]), programming hardware register values
([`kpc_set_config`]), and reading back counter accumulations per-thread,
per-CPU ([`kpc_get_thread_counters`], [`kpc_get_cpu_counters`]).

- **KPERF** (Kernel Performance): the sampling subsystem that fires actions
on timer triggers, enabling continuous profiling with configurable sample
sources ([`kperf_action_samplers_set`], [`kperf_timer_period_set`]).

Every KPC and KPERF function is a thin wrapper around a `sysctl` call into
the XNU kernel. The specific `sysctl` node is noted in each function's
documentation.

Because the framework is private, symbols are not available at link time.
[`KPerfSymbols.__init__`] resolves all function pointers eagerly from an
[`OwnedDLHandle`] at runtime, failing immediately if any symbol is missing.
"""

from std.os import abort
from std.ffi import _Global, OwnedDLHandle, c_char, c_int, c_size_t
from std.memory import OptionalUnsafePointer

from professor.ffi_utils import cast_optional_mut_ptr

# ===-----------------------------------------------------------------------===#
# Type Aliases
# ===-----------------------------------------------------------------------===#

comptime KPCConfig = UInt64

# ===-----------------------------------------------------------------------===#
# KPC class constants
# ===-----------------------------------------------------------------------===#

comptime KPC_CLASS_FIXED: UInt32 = 0
comptime KPC_CLASS_CONFIGURABLE: UInt32 = 1
comptime KPC_CLASS_POWER: UInt32 = 2
comptime KPC_CLASS_RAWPMU: UInt32 = 3

comptime KPC_CLASS_FIXED_MASK: UInt32 = 1 << KPC_CLASS_FIXED
comptime KPC_CLASS_CONFIGURABLE_MASK: UInt32 = 1 << KPC_CLASS_CONFIGURABLE
comptime KPC_CLASS_POWER_MASK: UInt32 = 1 << KPC_CLASS_POWER
comptime KPC_CLASS_RAWPMU_MASK: UInt32 = 1 << KPC_CLASS_RAWPMU

# ===-----------------------------------------------------------------------===#
# PMU version constants
# ===-----------------------------------------------------------------------===#

comptime KPC_PMU_ERROR: UInt32 = 0
comptime KPC_PMU_INTEL_V3: UInt32 = 1
comptime KPC_PMU_ARM_APPLE: UInt32 = 2
comptime KPC_PMU_INTEL_V2: UInt32 = 3
comptime KPC_PMU_ARM_V2: UInt32 = 4

# ===-----------------------------------------------------------------------===#
# KPC maximum number of counters
# ===-----------------------------------------------------------------------===#

comptime KPC_MAX_COUNTERS: Int = 32

# ===-----------------------------------------------------------------------===#
# KPERF sampler constants
# ===-----------------------------------------------------------------------===#

comptime KPERF_SAMPLER_TH_INFO: UInt32 = 1 << 0
comptime KPERF_SAMPLER_TH_SNAPSHOT: UInt32 = 1 << 1
comptime KPERF_SAMPLER_KSTACK: UInt32 = 1 << 2
comptime KPERF_SAMPLER_USTACK: UInt32 = 1 << 3
comptime KPERF_SAMPLER_PMC_THREAD: UInt32 = 1 << 4
comptime KPERF_SAMPLER_PMC_CPU: UInt32 = 1 << 5
comptime KPERF_SAMPLER_PMC_CONFIG: UInt32 = 1 << 6
comptime KPERF_SAMPLER_MEMINFO: UInt32 = 1 << 7
comptime KPERF_SAMPLER_TH_SCHEDULING: UInt32 = 1 << 8
comptime KPERF_SAMPLER_TH_DISPATCH: UInt32 = 1 << 9
comptime KPERF_SAMPLER_TK_SNAPSHOT: UInt32 = 1 << 10
comptime KPERF_SAMPLER_SYS_MEM: UInt32 = 1 << 11
comptime KPERF_SAMPLER_TH_INSCYC: UInt32 = 1 << 12
comptime KPERF_SAMPLER_TK_INFO: UInt32 = 1 << 13

comptime KPERF_ACTION_MAX: UInt32 = 32
comptime KPERF_TIMER_MAX: UInt32 = 8

# ===-----------------------------------------------------------------------===#
# Library Handle
# ===-----------------------------------------------------------------------===#


struct _KPerfHandle(Movable):
    var dylib: OwnedDLHandle
    var symbols: _KPerfSymbols

    def __init__(out self) raises:
        self.dylib = OwnedDLHandle(
            "/System/Library/PrivateFrameworks/kperf.framework/kperf"
        )
        self.symbols = _KPerfSymbols(self.dylib)


def _init_library() -> _KPerfHandle:
    try:
        return _KPerfHandle()
    except:
        abort("kperf library is unavailable")


comptime _KPERF_LIBRARY = _Global["KPERF_LIBRARY", _init_library]
"""Global handle for the kperf library."""


# ===-----------------------------------------------------------------------===#
# KPerf Functions
# ===-----------------------------------------------------------------------===#


@always_inline
def _sym() -> UnsafePointer[_KPerfSymbols, ImmutUntrackedOrigin]:
    try:
        return UnsafePointer(to=_KPERF_LIBRARY.get_or_create_ptr()[].symbols)
    except e:
        abort(t"kperf library unavailable: {e}")


@always_inline
def kpc_pmu_version() -> UInt32:
    """Gets the version of KPC that is running.

    Reads `kpc.pmu_version` via `sysctl`.

    Returns:
        One of the `KPC_PMU_*` version constants.
    """
    return _sym()[].kpc_pmu_version()


@always_inline
def kpc_cpu_string[
    origin: MutOrigin
](buf: UnsafePointer[c_char, origin], buf_size: c_size_t) -> c_int:
    """Prints the current CPU identification string to a buffer.

    The behavior is similar to `snprintf`. An example string is
    `"cpu_7_8_10b282dc_46"`. This string can be used to locate the PMC
    database in `/usr/share/kpep`.

    This function does not require root privileges.

    Reads `hw.cputype`, `hw.cpusubtype`, `hw.cpufamily`, and
    `machdep.cpu.model` via `sysctl`.

    Args:
        buf: Buffer to receive the CPU identification string.
        buf_size: Size of `buf` in bytes.

    Returns:
        The string length, or a negative value if an error occurs.
    """
    return _sym()[].kpc_cpu_string(
        buf.unsafe_origin_cast[MutUntrackedOrigin](), buf_size
    )


@always_inline
def kpc_set_counting(classes: UInt32) -> c_int:
    """Sets PMC classes to enable counting.

    `classes` is a combination of `KPC_CLASS_*_MASK` constants; pass 0
    to shut down counting.

    Writes `kpc.counting` via `sysctl`.

    Returns:
        0 for success.
    """
    return _sym()[].kpc_set_counting(classes)


@always_inline
def kpc_get_counting() -> UInt32:
    """Gets running PMC classes.

    Reads `kpc.counting` via `sysctl`.

    Returns:
        A combination of `KPC_CLASS_*_MASK` constants, or 0 if an error
        occurs or no class is set.
    """
    return _sym()[].kpc_get_counting()


@always_inline
def kpc_set_thread_counting(classes: UInt32) -> c_int:
    """Sets PMC classes to enable counting for the current thread.

    `classes` is a combination of `KPC_CLASS_*_MASK` constants; pass 0
    to shut down counting.

    Writes `kpc.thread_counting` via `sysctl`.

    Returns:
        0 for success.
    """
    return _sym()[].kpc_set_thread_counting(classes)


@always_inline
def kpc_get_thread_counting() -> UInt32:
    """Gets running PMC classes for the current thread.

    Reads `kpc.thread_counting` via `sysctl`.

    Returns:
        A combination of `KPC_CLASS_*_MASK` constants, or 0 if an error
        occurs or no class is set.
    """
    return _sym()[].kpc_get_thread_counting()


@always_inline
def kpc_get_config_count(classes: UInt32) -> UInt32:
    """Gets the number of config registers for a class mask.

    For example, Intel may return 1 for `KPC_CLASS_FIXED_MASK` and 4 for
    `KPC_CLASS_CONFIGURABLE_MASK`.

    This function does not require root privileges.

    Reads `kpc.config_count` via `sysctl`.

    Args:
        classes: A combination of `KPC_CLASS_*_MASK` constants.

    Returns:
        The number of config registers, or 0 if an error occurs or no class
        is set.
    """
    return _sym()[].kpc_get_config_count(classes)


@always_inline
def kpc_get_counter_count(classes: UInt32) -> UInt32:
    """Gets the number of counters for a class mask.

    For example, Intel may return 3 for `KPC_CLASS_FIXED_MASK` and 4 for
    `KPC_CLASS_CONFIGURABLE_MASK`.

    This function does not require root privileges.

    Reads `kpc.counter_count` via `sysctl`.

    Args:
        classes: A combination of `KPC_CLASS_*_MASK` constants.
    """
    return _sym()[].kpc_get_counter_count(classes)


@always_inline
def kpc_set_config[
    origin: MutOrigin, //
](classes: UInt32, config: UnsafePointer[KPCConfig, origin]) -> c_int:
    """Sets config registers.

    `config` should contain at least `kpc_get_config_count(classes)`
    elements.

    Reads `kpc.config_count` and writes `kpc.config` via `sysctl`.

    Args:
        classes: A combination of `KPC_CLASS_*_MASK` constants.
        config: Buffer containing the config register values.

    Returns:
        0 for success.
    """
    return _sym()[].kpc_set_config(
        classes, config.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kpc_get_config[
    origin: MutOrigin, //
](classes: UInt32, config: UnsafePointer[KPCConfig, origin]) -> c_int:
    """Gets config registers.

    `config` should have room for at least `kpc_get_config_count(classes)`
    elements.

    Reads `kpc.config_count` and `kpc.config` via `sysctl`.

    Args:
        classes: A combination of `KPC_CLASS_*_MASK` constants.
        config: Buffer to receive the config register values.

    Returns:
        0 for success.
    """
    return _sym()[].kpc_get_config(
        classes, config.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kpc_get_cpu_counters[
    cpu_origin: MutOrigin, buf_origin: MutOrigin, //
](
    all_cpus: Bool,
    classes: UInt32,
    cpu: OptionalUnsafePointer[c_int, cpu_origin],
    buf: UnsafePointer[UInt64, buf_origin],
) -> c_int:
    """Gets counter accumulations.

    If `all_cpus` is true, `buf` should contain at least
    `cpu_count * counter_count` elements. Otherwise, it should contain at
    least `counter_count` elements.

    Reads `hw.ncpu`, `kpc.counter_count`, and `kpc.counters` via `sysctl`.

    Args:
        all_cpus: True for all CPUs; false for the current CPU.
        classes: A combination of `KPC_CLASS_*_MASK` constants.
        cpu: Pointer to receive the current CPU id; may be null.
        buf: Buffer to receive counter values.

    Returns:
        0 for success.
    """
    return _sym()[].kpc_get_cpu_counters(
        all_cpus,
        classes,
        cast_optional_mut_ptr[MutUntrackedOrigin](cpu),
        buf.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpc_get_thread_counters[
    origin: MutOrigin, //
](tid: UInt32, buf_count: UInt32, buf: UnsafePointer[UInt64, origin],) -> c_int:
    """Gets counter accumulations for the current thread.

    Reads `kpc.thread_counters` via `sysctl`.

    Args:
        tid: Thread id; should be 0.
        buf_count: Number of elements in `buf`, not bytes; should be at
            least `kpc_get_counter_count(classes)`.
        buf: Buffer to receive counter values.

    Returns:
        0 for success.
    """
    return _sym()[].kpc_get_thread_counters(
        tid,
        buf_count,
        buf.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpc_force_all_ctrs_set(val: c_int) -> c_int:
    """Acquires or releases counters used by the Power Manager.

    Writes `kpc.force_all_ctrs` via `sysctl`.

    Args:
        val: 1 to acquire; 0 to release.

    Returns:
        0 for success.
    """
    return _sym()[].kpc_force_all_ctrs_set(val)


@always_inline
def kpc_force_all_ctrs_get[
    origin: MutOrigin, //
](val_out: UnsafePointer[c_int, origin]) -> c_int:
    """Gets the state of `force_all_ctrs`.

    Reads `kpc.force_all_ctrs` via `sysctl`.

    Args:
        val_out: Pointer to receive the current state.

    Returns:
        0 for success.
    """
    return _sym()[].kpc_force_all_ctrs_get(
        val_out.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kperf_action_count_set(count: UInt32) -> c_int:
    """Sets the number of actions. The maximum is `KPERF_ACTION_MAX`.

    Writes `kperf.action.count` via `sysctl`.

    Args:
        count: Number of actions.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_action_count_set(count)


@always_inline
def kperf_action_count_get[
    origin: MutOrigin, //
](count: UnsafePointer[UInt32, origin]) -> c_int:
    """Gets the number of actions.

    Reads `kperf.action.count` via `sysctl`.

    Args:
        count: Pointer to receive the number of actions.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_action_count_get(
        count.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kperf_action_samplers_set(actionid: UInt32, sample: UInt32) -> c_int:
    """Sets what an action samples when its trigger fires.

    The sample mask may include values such as `KPERF_SAMPLER_PMC_CPU`.

    Writes `kperf.action.samplers` via `sysctl`.

    Args:
        actionid: Action id.
        sample: Combination of `KPERF_SAMPLER_*` constants.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_action_samplers_set(actionid, sample)


@always_inline
def kperf_action_samplers_get[
    origin: MutOrigin, //
](actionid: UInt32, sample: UnsafePointer[UInt32, origin]) -> c_int:
    """Gets what an action samples when its trigger fires.

    Reads `kperf.action.samplers` via `sysctl`.

    Args:
        actionid: Action id.
        sample: Pointer to receive the sample mask.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_action_samplers_get(
        actionid, sample.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kperf_action_filter_set_by_task(actionid: UInt32, port: Int32) -> c_int:
    """Applies a task filter to an action. Pass -1 to disable the filter.

    Writes `kperf.action.filter_by_task` via `sysctl`.

    Args:
        actionid: Action id.
        port: Task port, or -1 to disable the filter.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_action_filter_set_by_task(actionid, port)


@always_inline
def kperf_action_filter_set_by_pid(actionid: UInt32, pid: Int32) -> c_int:
    """Applies a pid filter to an action. Pass -1 to disable the filter.

    Writes `kperf.action.filter_by_pid` via `sysctl`.

    Args:
        actionid: Action id.
        pid: Process id, or -1 to disable the filter.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_action_filter_set_by_pid(actionid, pid)


@always_inline
def kperf_timer_count_set(count: UInt32) -> c_int:
    """Sets the number of timer triggers. The maximum is `KPERF_TIMER_MAX`.

    Writes `kperf.timer.count` via `sysctl`.

    Args:
        count: Number of timer triggers.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_timer_count_set(count)


@always_inline
def kperf_timer_count_get[
    origin: MutOrigin, //
](count: UnsafePointer[UInt32, origin]) -> c_int:
    """Gets the number of timer triggers.

    Reads `kperf.timer.count` via `sysctl`.

    Args:
        count: Pointer to receive the number of timer triggers.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_timer_count_get(
        count.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kperf_timer_period_set(timerid: UInt32, period: UInt64) -> c_int:
    """Sets a timer period.

    Writes `kperf.timer.period` via `sysctl`.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_timer_period_set(timerid, period)


@always_inline
def kperf_timer_period_get[
    origin: MutOrigin, //
](timer_id: UInt32, period: UnsafePointer[UInt64, origin]) -> c_int:
    """Gets a timer period.

    Reads `kperf.timer.period` via `sysctl`.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_timer_period_get(
        timer_id, period.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kperf_timer_action_set(timerid: UInt32, actionid: UInt32) -> c_int:
    """Sets the action id associated with a timer.

    Writes `kperf.timer.action` via `sysctl`.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_timer_action_set(timerid, actionid)


@always_inline
def kperf_timer_action_get[
    origin: MutOrigin, //
](timer_id: UInt32, action_id: UnsafePointer[UInt32, origin]) -> c_int:
    """Gets the action id associated with a timer.

    Reads `kperf.timer.action` via `sysctl`.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_timer_action_get(
        timer_id, action_id.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kperf_sample_set(enabled: UInt32) -> c_int:
    """Enables or disables sampling.

    Writes `kperf.sampling` via `sysctl`.

    Args:
        enabled: Non-zero to enable sampling; 0 to disable it.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_sample_set(enabled)


@always_inline
def kperf_sample_get[
    origin: MutOrigin, //
](enabled: UnsafePointer[UInt32, origin]) -> c_int:
    """Gets whether sampling is active.

    Reads `kperf.sampling` via `sysctl`.

    Args:
        enabled: Pointer to receive the sampling state.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_sample_get(
        enabled.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kperf_reset() -> c_int:
    """Resets kperf: stops sampling, kdebug, timers, and actions.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_reset()


@always_inline
def kperf_timer_pet_set(timer_id: UInt32) -> c_int:
    """Sets which timer id performs PET (Profile Every Thread).

    Writes `kperf.timer.pet_timer` via `sysctl`.

    Args:
        timer_id: Timer id.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_timer_pet_set(timer_id)


@always_inline
def kperf_timer_pet_get[
    origin: MutOrigin, //
](timer_id: UnsafePointer[UInt32, origin]) -> c_int:
    """Gets which timer id performs PET (Profile Every Thread).

    Reads `kperf.timer.pet_timer` via `sysctl`.

    Args:
        timer_id: Pointer to receive the timer id.

    Returns:
        0 for success.
    """
    return _sym()[].kperf_timer_pet_get(
        timer_id.unsafe_origin_cast[MutUntrackedOrigin]()
    )


@always_inline
def kperf_ns_to_ticks(ns: UInt64) -> UInt64:
    """Converts nanoseconds to CPU ticks."""
    return _sym()[].kperf_ns_to_ticks(ns)


@always_inline
def kperf_ticks_to_ns(ticks: UInt64) -> UInt64:
    """Converts CPU ticks to nanoseconds."""
    return _sym()[].kperf_ticks_to_ns(ticks)


@always_inline
def kperf_tick_frequency() -> UInt64:
    """Gets the CPU tick frequency used by `mach_absolute_time`."""
    return _sym()[].kperf_tick_frequency()


# ===-----------------------------------------------------------------------===#
# Function pointer types for KPC
# ===-----------------------------------------------------------------------===#

comptime KPCCpuStringFn = def(
    UnsafePointer[c_char, MutUntrackedOrigin], c_size_t
) thin abi("C") -> c_int
comptime KPCPmuVersionFn = def() thin abi("C") -> UInt32
comptime KPCGetCountingFn = def() thin abi("C") -> UInt32
comptime KPCSetCountingFn = def(UInt32) thin abi("C") -> c_int
comptime KPCGetConfigCountFn = def(UInt32) thin abi("C") -> UInt32
comptime KPCConfigFn = def(
    UInt32, UnsafePointer[KPCConfig, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPCGetCounterCountFn = def(UInt32) thin abi("C") -> UInt32
comptime KPCGetCpuCountersFn = def(
    Bool,
    UInt32,
    OptionalUnsafePointer[c_int, MutUntrackedOrigin],
    UnsafePointer[UInt64, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPCGetThreadCountersFn = def(
    UInt32, UInt32, UnsafePointer[UInt64, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPCForceAllCtrsSetFn = def(c_int) thin abi("C") -> c_int
comptime KPCForceAllCtrsGetFn = def(
    UnsafePointer[c_int, MutUntrackedOrigin]
) thin abi("C") -> c_int

# ===-----------------------------------------------------------------------===#
# Function pointer types for KPERF
# ===-----------------------------------------------------------------------===#

comptime KPerfActionCountSetFn = def(UInt32) thin abi("C") -> c_int
comptime KPerfActionCountGetFn = def(
    UnsafePointer[UInt32, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPerfActionSamplersSetFn = def(UInt32, UInt32) thin abi("C") -> c_int
comptime KPerfActionSamplersGetFn = def(
    UInt32, UnsafePointer[UInt32, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPerfActionFilterSetFn = def(UInt32, Int32) thin abi("C") -> c_int
comptime KPerfTimerCountSetFn = def(UInt32) thin abi("C") -> c_int
comptime KPerfTimerCountGetFn = def(
    UnsafePointer[UInt32, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPerfTimerPeriodSetFn = def(UInt32, UInt64) thin abi("C") -> c_int
comptime KPerfTimerPeriodGetFn = def(
    UInt32, UnsafePointer[UInt64, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPerfTimerActionSetFn = def(UInt32, UInt32) thin abi("C") -> c_int
comptime KPerfTimerActionGetFn = def(
    UInt32, UnsafePointer[UInt32, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPerfTimerPetSetFn = def(UInt32) thin abi("C") -> c_int
comptime KPerfTimerPetGetFn = def(
    UnsafePointer[UInt32, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPerfSampleSetFn = def(UInt32) thin abi("C") -> c_int
comptime KPerfSampleGetFn = def(
    UnsafePointer[UInt32, MutUntrackedOrigin]
) thin abi("C") -> c_int
comptime KPerfResetFn = def() thin abi("C") -> c_int
comptime KPerfNsToTicksFn = def(UInt64) thin abi("C") -> UInt64
comptime KPerfTicksToNsFn = def(UInt64) thin abi("C") -> UInt64
comptime KPerfTickFrequencyFn = def() thin abi("C") -> UInt64

# ===-----------------------------------------------------------------------===#
# KPerf Symbols
# ===-----------------------------------------------------------------------===#


@fieldwise_init
struct _KPerfSymbols(Movable):
    """Eagerly-resolved function pointers for `kperf.framework`.

    Each field is a C function pointer loaded dynamically at runtime
    from Apple's private `kperf.framework`. The framework exposes two
    subsystems:

    - **KPC** (Kernel Performance Counters): enabling counter classes ([`kpc_set_counting`]),
      programming hardware registers ([`kpc_set_config`]), reading per-thread or per-CPU
      accumulations ([`kpc_get_thread_counters`], [`kpc_get_cpu_counters`]), and force-acquiring
      counters from the Power Manager ([`kpc_force_all_ctrs_set`]).

    - **KPERF** (Kernel Performance): the sampling subsystem that fires actions on timer triggers
      ([`kperf_action_samplers_set`], [`kperf_timer_period_set`]), with tick/nanosecond conversion
      helpers ([`kperf_ns_to_ticks`], [`kperf_ticks_to_ns`]).

    All function pointers are resolved eagerly by [`__init__`](Self::__init__).
    If any symbol is missing from the framework, loading fails immediately
    rather than deferring to first use. The resolved pointers remain valid for
    as long as the originating [`OwnedDLHandle`] is open.

    # Safety

    Every field is a thin C ABI function pointer. The caller is responsible
    for upholding the documented preconditions: buffer sizes, pointer
    validity, and privilege requirements. Most KPC/KPERF calls require root
    privileges.
    """

    var kpc_pmu_version: KPCPmuVersionFn
    var kpc_cpu_string: KPCCpuStringFn
    var kpc_set_counting: KPCSetCountingFn
    var kpc_get_counting: KPCGetCountingFn
    var kpc_set_thread_counting: KPCSetCountingFn
    var kpc_get_thread_counting: KPCGetCountingFn
    var kpc_get_config_count: KPCGetConfigCountFn
    var kpc_get_counter_count: KPCGetCounterCountFn
    var kpc_set_config: KPCConfigFn
    var kpc_get_config: KPCConfigFn
    var kpc_get_cpu_counters: KPCGetCpuCountersFn
    var kpc_get_thread_counters: KPCGetThreadCountersFn
    var kpc_force_all_ctrs_set: KPCForceAllCtrsSetFn
    var kpc_force_all_ctrs_get: KPCForceAllCtrsGetFn
    var kperf_action_count_set: KPerfActionCountSetFn
    var kperf_action_count_get: KPerfActionCountGetFn
    var kperf_action_samplers_set: KPerfActionSamplersSetFn
    var kperf_action_samplers_get: KPerfActionSamplersGetFn
    var kperf_action_filter_set_by_task: KPerfActionFilterSetFn
    var kperf_action_filter_set_by_pid: KPerfActionFilterSetFn
    var kperf_timer_count_set: KPerfTimerCountSetFn
    var kperf_timer_count_get: KPerfTimerCountGetFn
    var kperf_timer_period_set: KPerfTimerPeriodSetFn
    var kperf_timer_period_get: KPerfTimerPeriodGetFn
    var kperf_timer_action_set: KPerfTimerActionSetFn
    var kperf_timer_action_get: KPerfTimerActionGetFn
    var kperf_sample_set: KPerfSampleSetFn
    var kperf_sample_get: KPerfSampleGetFn
    var kperf_reset: KPerfResetFn
    var kperf_timer_pet_set: KPerfTimerPetSetFn
    var kperf_timer_pet_get: KPerfTimerPetGetFn
    var kperf_ns_to_ticks: KPerfNsToTicksFn
    var kperf_ticks_to_ns: KPerfTicksToNsFn
    var kperf_tick_frequency: KPerfTickFrequencyFn

    def __init__(out self, handle: OwnedDLHandle):
        self.kpc_pmu_version = handle.get_function[KPCPmuVersionFn](
            "kpc_pmu_version"
        )
        self.kpc_cpu_string = handle.get_function[KPCCpuStringFn](
            "kpc_cpu_string"
        )
        self.kpc_set_counting = handle.get_function[KPCSetCountingFn](
            "kpc_set_counting"
        )
        self.kpc_get_counting = handle.get_function[KPCGetCountingFn](
            "kpc_get_counting"
        )
        self.kpc_set_thread_counting = handle.get_function[KPCSetCountingFn](
            "kpc_set_thread_counting"
        )
        self.kpc_get_thread_counting = handle.get_function[KPCGetCountingFn](
            "kpc_get_thread_counting"
        )
        self.kpc_get_config_count = handle.get_function[KPCGetConfigCountFn](
            "kpc_get_config_count"
        )
        self.kpc_get_counter_count = handle.get_function[KPCGetCounterCountFn](
            "kpc_get_counter_count"
        )
        self.kpc_set_config = handle.get_function[KPCConfigFn]("kpc_set_config")
        self.kpc_get_config = handle.get_function[KPCConfigFn]("kpc_get_config")
        self.kpc_get_cpu_counters = handle.get_function[KPCGetCpuCountersFn](
            "kpc_get_cpu_counters"
        )
        self.kpc_get_thread_counters = handle.get_function[
            KPCGetThreadCountersFn
        ]("kpc_get_thread_counters")
        self.kpc_force_all_ctrs_set = handle.get_function[KPCForceAllCtrsSetFn](
            "kpc_force_all_ctrs_set"
        )
        self.kpc_force_all_ctrs_get = handle.get_function[KPCForceAllCtrsGetFn](
            "kpc_force_all_ctrs_get"
        )
        self.kperf_action_count_set = handle.get_function[
            KPerfActionCountSetFn
        ]("kperf_action_count_set")
        self.kperf_action_count_get = handle.get_function[
            KPerfActionCountGetFn
        ]("kperf_action_count_get")
        self.kperf_action_samplers_set = handle.get_function[
            KPerfActionSamplersSetFn
        ]("kperf_action_samplers_set")
        self.kperf_action_samplers_get = handle.get_function[
            KPerfActionSamplersGetFn
        ]("kperf_action_samplers_get")
        self.kperf_action_filter_set_by_task = handle.get_function[
            KPerfActionFilterSetFn
        ]("kperf_action_filter_set_by_task")
        self.kperf_action_filter_set_by_pid = handle.get_function[
            KPerfActionFilterSetFn
        ]("kperf_action_filter_set_by_pid")
        self.kperf_timer_count_set = handle.get_function[KPerfTimerCountSetFn](
            "kperf_timer_count_set"
        )
        self.kperf_timer_count_get = handle.get_function[KPerfTimerCountGetFn](
            "kperf_timer_count_get"
        )
        self.kperf_timer_period_set = handle.get_function[
            KPerfTimerPeriodSetFn
        ]("kperf_timer_period_set")
        self.kperf_timer_period_get = handle.get_function[
            KPerfTimerPeriodGetFn
        ]("kperf_timer_period_get")
        self.kperf_timer_action_set = handle.get_function[
            KPerfTimerActionSetFn
        ]("kperf_timer_action_set")
        self.kperf_timer_action_get = handle.get_function[
            KPerfTimerActionGetFn
        ]("kperf_timer_action_get")
        self.kperf_sample_set = handle.get_function[KPerfSampleSetFn](
            "kperf_sample_set"
        )
        self.kperf_sample_get = handle.get_function[KPerfSampleGetFn](
            "kperf_sample_get"
        )
        self.kperf_reset = handle.get_function[KPerfResetFn]("kperf_reset")
        self.kperf_timer_pet_set = handle.get_function[KPerfTimerPetSetFn](
            "kperf_timer_pet_set"
        )
        self.kperf_timer_pet_get = handle.get_function[KPerfTimerPetGetFn](
            "kperf_timer_pet_get"
        )
        self.kperf_ns_to_ticks = handle.get_function[KPerfNsToTicksFn](
            "kperf_ns_to_ticks"
        )
        self.kperf_ticks_to_ns = handle.get_function[KPerfTicksToNsFn](
            "kperf_ticks_to_ns"
        )
        self.kperf_tick_frequency = handle.get_function[KPerfTickFrequencyFn](
            "kperf_tick_frequency"
        )
