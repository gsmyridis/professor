from std.ffi import c_char, c_int, c_size_t, OwnedDLHandle
from std.memory import OptionalUnsafePointer
from std.sys import size_of

from .kperf import KPCConfig

# ===-----------------------------------------------------------------------===#
# Aliases
# ===-----------------------------------------------------------------------===#

comptime ConstCStringPointer = OptionalUnsafePointer[
    c_char, origin=ImmutAnyOrigin
]
"""C `const char*` type."""

comptime c_void = OptionalUnsafePointer[NoneType, MutUntrackedOrigin]
"""C `void*` type."""

# ===-----------------------------------------------------------------------===#
# KPEP architecture constants
# ===-----------------------------------------------------------------------===#

comptime KPEP_ARCH_I386: UInt32 = 0
comptime KPEP_ARCH_X86_64: UInt32 = 1
comptime KPEP_ARCH_ARM: UInt32 = 2
comptime KPEP_ARCH_ARM64: UInt32 = 3

# ===-----------------------------------------------------------------------===#
# KPEP Event
# ===-----------------------------------------------------------------------===#

@fieldwise_init
struct KPEPEvent(Copyable):
    """KPEP event."""

    # ===-----------------------------------------------------------------------===#
    # Aliases
    # ===-----------------------------------------------------------------------===#

    comptime Pointer = OptionalUnsafePointer[Self, MutUntrackedOrigin]
    """Pointer to a KPEPEvent."""

    comptime PointerPointer = OptionalUnsafePointer[Self.Pointer, MutUntrackedOrigin]
    """Pointer to a pointer to a KPEPEvent."""

    # ===-----------------------------------------------------------------------===#
    # Fields
    # ===-----------------------------------------------------------------------===#

    var name: ConstCStringPointer
    """Unique name of an event, such as `"INST_RETIRED.ANY"`."""

    var description: ConstCStringPointer
    """Description of this event."""

    var errata: ConstCStringPointer
    """Errata, currently NULL."""

    var alias_name: ConstCStringPointer
    """Alias name, such as `"Instructions"`, `"Cycles"`."""

    var fallback: ConstCStringPointer
    """Fallback event name for fixed counter."""

    var mask: UInt32
    """Hardware event selector mask."""

    var number: UInt8
    """Event number (selector value written to the PMC config register)."""

    var umask: UInt8
    """Intel PMC umask value, populated from the plist `"umask"` key.

    Only set on `x86_64`; always zero for `ARM`. The name is a holdover from
    Intel's PMC naming conventions. Despite what older references call it,
    this is *not* an "is this a fixed counter" flag.
    """

    var _padding: UInt8

    var is_fixed: UInt8
    """Bit 0: event has a fixed counter entry in the plist and must be placed
    in a fixed counter slot. Set during `_event_init` when the plist contains
    a `"fixed_counter"` key; the fallback event name (if any) is read
    alongside it.
    """

# ===-----------------------------------------------------------------------===#
# KPEP Database
# ===-----------------------------------------------------------------------===#

struct KPEPDb(Copyable):
    """KPEP Database."""

    # ===-----------------------------------------------------------------------===#
    # Aliases
    # ===-----------------------------------------------------------------------===#

    comptime Pointer = OptionalUnsafePointer[KPEPDb, MutUntrackedOrigin]
    """Pointer to a `KPEPDb`."""

    # ===-----------------------------------------------------------------------===#
    # Fields
    # ===-----------------------------------------------------------------------===#

    var name: ConstCStringPointer
    """Database name from the plist `"name"` key (internal identifier)."""

    var cpu_id: ConstCStringPointer
    """CPU identifier string, such as `"cpu_7_8_10b282dc"`."""

    var marketing_name: ConstCStringPointer
    """Marketing name, such as `"Apple M1"`.

    This is what `kpep_db_name` returns.
    """

    var plist_data: c_void
    """Serialized plist in binary format v1.0 (`CFDataRef`).
    Created lazily by `kpep_db_serialize`.
    """

    var event_map: c_void
    """All events keyed by event name (`CFDictionaryRef`: `CFString -> *mut KPEPEvent`)."""

    var event_arr: KPEPEvent.Pointer
    """Contiguous event array (`size_of[KPEPEvent]() * event_count`)."""

    var fixed_event_arr: KPEPEvent.PointerPointer
    """Fixed counter event pointers (`size_of[KPEPEvent.Pointer]() * fixed_counter_count`)."""

    var alias_map: c_void
    """All aliases keyed by alias name (`CFDictionaryRef`: `CFString -> *mut KPEPEvent`).
    Searched first by `kpep_db_event`.
    """

    var _padding_1: c_size_t
    var _padding_2: c_size_t
    var _padding_3: c_size_t

    var event_count: c_size_t
    """Total number of events in `KPEPDb.event_arr`."""

    var alias_count: c_size_t

    var fixed_counter_count: c_size_t
    """`popcount(fixed_counter_bits)`."""

    var config_counter_count: c_size_t
    """`popcount(config_counter_bits)`."""

    var power_counter_count: c_size_t
    """`popcount(power_counter_bits)`."""

    var architecture: UInt32
    """See `KPEP_ARCH_*` constants."""

    var fixed_counter_bits: UInt32
    """Bitmap of available fixed counters."""

    var config_counter_bits: UInt32
    """Bitmap of available configurable counters."""

    var power_counter_bits: UInt32
    """Bitmap of available power counters."""

# ===-----------------------------------------------------------------------===#
# KPEP Config
# ===-----------------------------------------------------------------------===#

struct KPEPConfig(Copyable):

    # ===-----------------------------------------------------------------------===#
    # Aliases
    # ===-----------------------------------------------------------------------===#

    comptime Pointer = OptionalUnsafePointer[Self, MutUntrackedOrigin]
    """Pointer to `KPEPConfig`."""

    # ===-----------------------------------------------------------------------===#
    # Fields
    # ===-----------------------------------------------------------------------===#

    var db: KPEPDb.Pointer

    var ev_arr: KPEPEvent.PointerPointer
    """Event pointers (`size_of[KPEPEvent]() * counter_count`).
    Initially it is set to `NULL`.
    """

    var ev_map: OptionalUnsafePointer[c_size_t, MutUntrackedOrigin]
    """Maps event index -> absolute counter slot (`size_of[UInt]() * counter_count`), initially set to 0.

    `kpep_config_kpc_map` copies from this array, optionally subtracting
    `fixed_counter_count` to produce class-relative indices.
    """

    var ev_idx: OptionalUnsafePointer[c_size_t, MutUntrackedOrigin]
    """Maps counter slot -> event index (`size_of[UInt]() * counter_count`),
    initially set to `UInt.MAX` (-1). It is the inverse of `ev_map`.
    """

    var flags: OptionalUnsafePointer[UInt32, MutUntrackedOrigin]
    """Per-counter flags (`size_of[UInt32]() * counter_count`), initially 0."""

    var kpc_periods: OptionalUnsafePointer[UInt64, MutUntrackedOrigin]
    """KPC sampling periods (`size_of[UInt64]() * counter_count`), initially 0."""

    var event_count: c_size_t
    """Number of events added via `kpep_config_add_event`."""

    var counter_count: c_size_t
    """Total number of hardware counters (fixed + configurable), set from
    `kpep_db_counters_count(db, FIXED | CONFIGURABLE)` at creation.
    """

    var classes: UInt32
    """Active counter class mask (see `KPC_CLASS_*_MASK` constants).
    Built incrementally by `kpep_config_add_event`.
    """

    var config_counter: UInt32
    var power_counter: UInt32
    var _padding: UInt32


# ===-----------------------------------------------------------------------===#
# Error codes
# ===-----------------------------------------------------------------------===#

comptime KPEP_CONFIG_ERROR_NONE: Int = 0
comptime KPEP_CONFIG_ERROR_INVALID_ARGUMENT: Int = 1
comptime KPEP_CONFIG_ERROR_OUT_OF_MEMORY: Int = 2
comptime KPEP_CONFIG_ERROR_IO: Int = 3
comptime KPEP_CONFIG_ERROR_BUFFER_TOO_SMALL: Int = 4
comptime KPEP_CONFIG_ERROR_CUR_SYSTEM_UNKNOWN: Int = 5
comptime KPEP_CONFIG_ERROR_DB_PATH_INVALID: Int = 6
comptime KPEP_CONFIG_ERROR_DB_NOT_FOUND: Int = 7
comptime KPEP_CONFIG_ERROR_DB_ARCH_UNSUPPORTED: Int = 8
comptime KPEP_CONFIG_ERROR_DB_VERSION_UNSUPPORTED: Int = 9
comptime KPEP_CONFIG_ERROR_DB_CORRUPT: Int = 10
comptime KPEP_CONFIG_ERROR_EVENT_NOT_FOUND: Int = 11
comptime KPEP_CONFIG_ERROR_CONFLICTING_EVENTS: Int = 12
comptime KPEP_CONFIG_ERROR_COUNTERS_NOT_FORCED: Int = 13
comptime KPEP_CONFIG_ERROR_EVENT_UNAVAILABLE: Int = 14
comptime KPEP_CONFIG_ERROR_ERRNO: Int = 15
comptime KPEP_CONFIG_ERROR_MAX: Int = 16


def kpep_config_error_desc(code: Int) -> String:
    if code == KPEP_CONFIG_ERROR_NONE:
        return "none"
    if code == KPEP_CONFIG_ERROR_INVALID_ARGUMENT:
        return "invalid argument"
    if code == KPEP_CONFIG_ERROR_OUT_OF_MEMORY:
        return "out of memory"
    if code == KPEP_CONFIG_ERROR_IO:
        return "I/O"
    if code == KPEP_CONFIG_ERROR_BUFFER_TOO_SMALL:
        return "buffer too small"
    if code == KPEP_CONFIG_ERROR_CUR_SYSTEM_UNKNOWN:
        return "current system unknown"
    if code == KPEP_CONFIG_ERROR_DB_PATH_INVALID:
        return "database path invalid"
    if code == KPEP_CONFIG_ERROR_DB_NOT_FOUND:
        return "database not found"
    if code == KPEP_CONFIG_ERROR_DB_ARCH_UNSUPPORTED:
        return "database architecture unsupported"
    if code == KPEP_CONFIG_ERROR_DB_VERSION_UNSUPPORTED:
        return "database version unsupported"
    if code == KPEP_CONFIG_ERROR_DB_CORRUPT:
        return "database corrupt"
    if code == KPEP_CONFIG_ERROR_EVENT_NOT_FOUND:
        return "event not found"
    if code == KPEP_CONFIG_ERROR_CONFLICTING_EVENTS:
        return "conflicting events"
    if code == KPEP_CONFIG_ERROR_COUNTERS_NOT_FORCED:
        return "all counters must be forced"
    if code == KPEP_CONFIG_ERROR_EVENT_UNAVAILABLE:
        return "event unavailable"
    if code == KPEP_CONFIG_ERROR_ERRNO:
        return "check errno"
    return "unknown error"


# ===-----------------------------------------------------------------------===#
# Function pointer types
# ===-----------------------------------------------------------------------===#

comptime KPEPConfigCreateFn = def(
    KPEPDb.Pointer, OptionalUnsafePointer[KPEPConfig.Pointer, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPConfigFreeFn = def(KPEPConfig.Pointer) thin abi("C") -> NoneType
comptime KPEPConfigAddEventFn = def(
    KPEPConfig.Pointer,
    OptionalUnsafePointer[KPEPEvent.Pointer, MutAnyOrigin],
    UInt32,
    OptionalUnsafePointer[UInt32, MutAnyOrigin],
) thin abi("C") -> c_int
comptime KPEPConfigRemoveEventFn = def(KPEPConfig.Pointer, c_size_t) thin abi(
    "C"
) -> c_int
comptime KPEPConfigForceCountersFn = def(KPEPConfig.Pointer) thin abi("C") -> c_int
comptime KPEPConfigEventsCountFn = def(
    KPEPConfig.Pointer, OptionalUnsafePointer[c_size_t, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPConfigEventsFn = def(
    KPEPConfig.Pointer,
    OptionalUnsafePointer[KPEPEvent.Pointer, MutAnyOrigin],
    c_size_t,
) thin abi("C") -> c_int
comptime KPEPConfigKPCFn = def(
    KPEPConfig.Pointer, OptionalUnsafePointer[KPCConfig, MutAnyOrigin], c_size_t
) thin abi("C") -> c_int
comptime KPEPConfigKPCCountFn = def(
    KPEPConfig.Pointer, OptionalUnsafePointer[c_size_t, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPConfigKPCClassesFn = def(
    KPEPConfig.Pointer, OptionalUnsafePointer[UInt32, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPConfigKPCMapFn = def(
    KPEPConfig.Pointer, OptionalUnsafePointer[c_size_t, MutAnyOrigin], c_size_t
) thin abi("C") -> c_int
comptime KPEPDbCreateFn = def(
    ConstCStringPointer, OptionalUnsafePointer[KPEPDb.Pointer, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPDbFreeFn = def(KPEPDb.Pointer) thin abi("C") -> NoneType
comptime KPEPDbNameFn = def(
    KPEPDb.Pointer, OptionalUnsafePointer[ConstCStringPointer, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPDbAliasesCountFn = def(
    KPEPDb.Pointer, OptionalUnsafePointer[c_size_t, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPDbAliasesFn = def(
    KPEPDb.Pointer, OptionalUnsafePointer[ConstCStringPointer, MutAnyOrigin], c_size_t
) thin abi("C") -> c_int
comptime KPEPDbCountersCountFn = def(
    KPEPDb.Pointer, UInt8, OptionalUnsafePointer[c_size_t, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPDbEventsCountFn = def(
    KPEPDb.Pointer, OptionalUnsafePointer[c_size_t, MutAnyOrigin]
) thin abi("C") -> c_int
comptime KPEPDbEventsFn = def(
    KPEPDb.Pointer, OptionalUnsafePointer[KPEPEvent.Pointer, MutAnyOrigin], c_size_t
) thin abi("C") -> c_int
comptime KPEPDbEventFn = def(
    KPEPDb.Pointer,
    ConstCStringPointer,
    OptionalUnsafePointer[KPEPEvent.Pointer, MutAnyOrigin],
) thin abi("C") -> c_int
comptime KPEPEventStringFn = def(
    KPEPEvent.Pointer, OptionalUnsafePointer[ConstCStringPointer, MutAnyOrigin]
) thin abi("C") -> c_int


# ===-----------------------------------------------------------------------===#
# KPEP Symbols
# ===-----------------------------------------------------------------------===#

struct KPEPSymbols(Copyable):
    """Eagerly-resolved function pointers for `kperfdata.framework`.

    Each field is a C function pointer obtained via `dlsym` from Apple's
    private `kperfdata.framework`. The framework provides the Kernel
    Performance Event Programming (KPEP) interface, which sits between
    human-readable event names such as `"INST_RETIRED.ANY"` or `"Cycles"` and
    the raw KPC hardware registers.

    The KPEP API is organized around three object types:

    - **`KPEPDb`**: a parsed PMC event database opened from plist files in
      `/usr/share/kpep/`. Relevant functions include `kpep_db_create`,
      `kpep_db_free`, `kpep_db_event`, and `kpep_db_events`.

    - **`KPEPEvent`**: a single PMC event descriptor with its hardware
      selector, name, alias, and fixed-counter flag. Relevant functions include
      `kpep_event_name`, `kpep_event_alias`, and `kpep_event_description`.

    - **`KPEPConfig`**: a mutable configuration builder that maps events to
      counter registers. Relevant functions include `kpep_config_create`,
      `kpep_config_add_event`, `kpep_config_kpc`, and `kpep_config_kpc_map`.

    All function pointers are resolved eagerly by `__init__`. If any symbol is
    missing from the framework, loading fails immediately rather than
    deferring to first use. The resolved pointers remain valid for as long as
    the originating `OwnedDLHandle` is open.

    # Safety

    Every field is a thin C ABI function pointer. The caller is responsible
    for upholding the documented preconditions: buffer sizes, pointer
    validity, and correct lifetime management of the opaque KPEP objects.
    """

    var kpep_config_create: KPEPConfigCreateFn
    """Creates a new configuration builder for a database.

    Args:
        db: Database handle previously obtained from `kpep_db_create`.
        cfg_ptr: Pointer to receive the newly allocated config. Free it with
            `kpep_config_free`.

    Returns:
        0 for success.
    """

    var kpep_config_free: KPEPConfigFreeFn
    """Frees a config previously allocated by `kpep_config_create`."""

    var kpep_config_add_event: KPEPConfigAddEventFn
    """Adds an event to a configuration.

    Args:
        cfg: Config to modify.
        ev_ptr: Pointer to an event pointer obtained from `kpep_db_event`.
        flag: 0 to count in all modes; 1 for user space only.
        err: Optional error bitmap pointer. If the return value is
            `KPEP_CONFIG_ERROR_CONFLICTING_EVENTS`, each set bit identifies a
            conflicting event index.

    Returns:
        0 for success.
    """

    var kpep_config_remove_event: KPEPConfigRemoveEventFn
    """Removes the event at `idx` from a configuration.

    Returns:
        0 for success.
    """

    var kpep_config_force_counters: KPEPConfigForceCountersFn
    """Marks a configuration as needing force-acquired counters.

    After calling this, `kpep_config_kpc` produces register values that require
    `kpc_force_all_ctrs_set(1)` to have been called first.

    Returns:
        0 for success.
    """

    var kpep_config_events_count: KPEPConfigEventsCountFn
    """Gets the number of events added to a config.

    Returns:
        0 for success.
    """

    var kpep_config_events: KPEPConfigEventsFn
    """Gets all event pointers from a configuration.

    Args:
        cfg: Config to query.
        buf: Buffer to receive event pointers.
        buf_size: Buffer size in bytes; should be at least
            `kpep_config_events_count() * size_of[KPEPEvent.Pointer]()`.

    Returns:
        0 for success.
    """

    var kpep_config_kpc: KPEPConfigKPCFn
    """Gets KPC register configuration values.

    Args:
        cfg: Config to query.
        buf: Buffer to receive register config values.
        buf_size: Buffer size in bytes; should be at least
            `kpep_config_kpc_count() * size_of[KPCConfig]()`.

    Returns:
        0 for success.
    """

    var kpep_config_kpc_count: KPEPConfigKPCCountFn
    """Gets the number of KPC register config values.

    Returns:
        0 for success.
    """

    var kpep_config_kpc_classes: KPEPConfigKPCClassesFn
    """Gets the active KPC counter class mask.

    `classes_ptr` receives a combination of `KPC_CLASS_*_MASK` constants.

    Returns:
        0 for success.
    """

    var kpep_config_kpc_map: KPEPConfigKPCMapFn
    """Gets the mapping from event index to hardware counter slot.

    Args:
        cfg: Config to query.
        buf: Buffer to receive one hardware counter slot index per event.
        buf_size: Buffer size in bytes; should be at least
            `kpep_config_events_count() * size_of[c_size_t]()`.

    Returns:
        0 for success.
    """

    var kpep_db_create: KPEPDbCreateFn
    """Opens a KPEP database file.

    Searches `/usr/share/kpep/` or `/usr/local/share/kpep/`.

    Args:
        name: Database file name, such as `"haswell"` or
            `"cpu_100000c_1_92fb37c8"`. Pass null to auto-detect the current
            CPU.
        db_ptr: Pointer to receive the newly allocated database. Free it with
            `kpep_db_free`.

    Returns:
        0 for success.
    """

    var kpep_db_free: KPEPDbFreeFn
    """Frees a database previously allocated by `kpep_db_create`."""

    var kpep_db_name: KPEPDbNameFn
    """Gets a database's marketing name, such as `"Apple M1"`.

    Returns:
        0 for success.
    """

    var kpep_db_aliases_count: KPEPDbAliasesCountFn
    """Gets the number of event aliases in a database.

    Returns:
        0 for success.
    """

    var kpep_db_aliases: KPEPDbAliasesFn
    """Gets all alias strings from a database.

    Args:
        db: Database to query.
        buf: Buffer to receive alias string pointers.
        buf_size: Buffer size in bytes; should be at least
            `kpep_db_aliases_count() * size_of[ConstCStringPointer]()`.

    Returns:
        0 for success.
    """

    var kpep_db_counters_count: KPEPDbCountersCountFn
    """Gets the number of counters for a class mask.

    `classes` is 1 for fixed, 2 for configurable, or 3 for both.

    Returns:
        0 for success.
    """

    var kpep_db_events_count: KPEPDbEventsCountFn
    """Gets the total number of events in a database.

    Returns:
        0 for success.
    """

    var kpep_db_events: KPEPDbEventsFn
    """Gets all event pointers from a database.

    Args:
        db: Database to query.
        buf: Buffer to receive event pointers.
        buf_size: Buffer size in bytes; should be at least
            `kpep_db_events_count() * size_of[KPEPEvent.Pointer]()`.

    Returns:
        0 for success.
    """

    var kpep_db_event: KPEPDbEventFn
    """Looks up one event by name or alias.

    Returns:
        0 for success.
    """

    var kpep_event_name: KPEPEventStringFn
    """Gets an event's unique name, such as `"INST_ALL"`.

    Returns:
        0 for success.
    """

    var kpep_event_alias: KPEPEventStringFn
    """Gets an event's alias, such as `"Instructions"`, if one exists.

    Returns:
        0 for success.
    """

    var kpep_event_description: KPEPEventStringFn
    """Gets an event's human-readable description, if available.

    Returns:
        0 for success.
    """

    def __init__(out self, handle: OwnedDLHandle):
        self.kpep_config_create = handle.get_function[KPEPConfigCreateFn](
            "kpep_config_create"
        )
        self.kpep_config_free = handle.get_function[KPEPConfigFreeFn](
            "kpep_config_free"
        )
        self.kpep_config_add_event = handle.get_function[KPEPConfigAddEventFn](
            "kpep_config_add_event"
        )
        self.kpep_config_remove_event = handle.get_function[
            KPEPConfigRemoveEventFn
        ]("kpep_config_remove_event")
        self.kpep_config_force_counters = handle.get_function[
            KPEPConfigForceCountersFn
        ]("kpep_config_force_counters")
        self.kpep_config_events_count = handle.get_function[
            KPEPConfigEventsCountFn
        ]("kpep_config_events_count")
        self.kpep_config_events = handle.get_function[KPEPConfigEventsFn](
            "kpep_config_events"
        )
        self.kpep_config_kpc = handle.get_function[KPEPConfigKPCFn](
            "kpep_config_kpc"
        )
        self.kpep_config_kpc_count = handle.get_function[KPEPConfigKPCCountFn](
            "kpep_config_kpc_count"
        )
        self.kpep_config_kpc_classes = handle.get_function[
            KPEPConfigKPCClassesFn
        ]("kpep_config_kpc_classes")
        self.kpep_config_kpc_map = handle.get_function[KPEPConfigKPCMapFn](
            "kpep_config_kpc_map"
        )
        self.kpep_db_create = handle.get_function[KPEPDbCreateFn](
            "kpep_db_create"
        )
        self.kpep_db_free = handle.get_function[KPEPDbFreeFn]("kpep_db_free")
        self.kpep_db_name = handle.get_function[KPEPDbNameFn]("kpep_db_name")
        self.kpep_db_aliases_count = handle.get_function[KPEPDbAliasesCountFn](
            "kpep_db_aliases_count"
        )
        self.kpep_db_aliases = handle.get_function[KPEPDbAliasesFn](
            "kpep_db_aliases"
        )
        self.kpep_db_counters_count = handle.get_function[
            KPEPDbCountersCountFn
        ]("kpep_db_counters_count")
        self.kpep_db_events_count = handle.get_function[KPEPDbEventsCountFn](
            "kpep_db_events_count"
        )
        self.kpep_db_events = handle.get_function[KPEPDbEventsFn](
            "kpep_db_events"
        )
        self.kpep_db_event = handle.get_function[KPEPDbEventFn]("kpep_db_event")
        self.kpep_event_name = handle.get_function[KPEPEventStringFn](
            "kpep_event_name"
        )
        self.kpep_event_alias = handle.get_function[KPEPEventStringFn](
            "kpep_event_alias"
        )
        self.kpep_event_description = handle.get_function[KPEPEventStringFn](
            "kpep_event_description"
        )
