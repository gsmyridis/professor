from std.os import abort
from std.ffi import _Global, OwnedDLHandle, c_char, c_int, c_size_t
from std.memory import OptionalUnsafePointer, OpaquePointer
from std.sys import size_of
from .kperf import KPCConfig
from professor.ffi_utils import cast_optional_mut_ptr
from professor.ffi_utils import ConstCStringPointer, c_void

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

    # ===-------------------------------------------------------------------===#
    # Aliases
    # ===-------------------------------------------------------------------===#

    comptime MutPointerType = UnsafePointer[Self, MutUntrackedOrigin]
    """Non-nullable mutable pointer to KPEPEvent with untracked origin."""

    # ===-------------------------------------------------------------------===#
    # Fields
    # ===-------------------------------------------------------------------===#

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

    var _reserved: UInt64
    """Trailing reserved bytes. `size_of[KPEPEvent]()` must be 56 to match
    the real `kpep_event` C struct; without this field elements past index 0
    in a `KPEPEvent` array are misaligned (verified empirically: indexing
    `kpep_db_t.event_arr` with a 48-byte stride reads garbage for index 1+).
    """


# ===-----------------------------------------------------------------------===#
# KPEP Database
# ===-----------------------------------------------------------------------===#


struct KPEPDb(Copyable):
    """KPEP Database."""

    # ===-------------------------------------------------------------------===#
    # Aliases
    # ===-------------------------------------------------------------------===#

    comptime MutPointerType = UnsafePointer[Self, MutUntrackedOrigin]
    """Non-nullable mutable pointer to KPEPDb with untracked origin."""

    # ===-------------------------------------------------------------------===#
    # Fields
    # ===-------------------------------------------------------------------===#

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

    var event_arr: OptionalUnsafePointer[KPEPEvent, MutUntrackedOrigin]
    """Contiguous event array (`size_of[KPEPEvent]() * event_count`)."""

    var fixed_event_arr: OptionalUnsafePointer[
        KPEPEvent.MutPointerType, MutUntrackedOrigin
    ]
    """Fixed counter event pointers (`size_of[OptionalUnsafePointer[KPEPEvent.MutPointerType, MutUntrackedOrigin]]() * fixed_counter_count`)."""

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
    # ===-------------------------------------------------------------------===#
    # Aliases
    # ===-------------------------------------------------------------------===#

    comptime MutPointerType = UnsafePointer[Self, MutUntrackedOrigin]
    """Non-nullable mutable pointer to KPEPConfig with untracked origin."""

    # ===-------------------------------------------------------------------===#
    # Fields
    # ===-------------------------------------------------------------------===#

    var db: KPEPDb.MutPointerType

    var ev_arr: OptionalUnsafePointer[
        KPEPEvent.MutPointerType, MutUntrackedOrigin
    ]
    """Event pointers (`size_of[KPEPEvent]() * counter_count`).
    Initially it is set to `NULL`.
    """

    var ev_map: OptionalUnsafePointer[c_size_t, MutUntrackedOrigin]
    """Maps event index -> absolute counter slot (`size_of[UInt]() * counter_count`),
    initially set to 0.

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

comptime KPEP_CONFIG_ERROR_NONE: c_int = 0
comptime KPEP_CONFIG_ERROR_INVALID_ARGUMENT: c_int = 1
comptime KPEP_CONFIG_ERROR_OUT_OF_MEMORY: c_int = 2
comptime KPEP_CONFIG_ERROR_IO: c_int = 3
comptime KPEP_CONFIG_ERROR_BUFFER_TOO_SMALL: c_int = 4
comptime KPEP_CONFIG_ERROR_CUR_SYSTEM_UNKNOWN: c_int = 5
comptime KPEP_CONFIG_ERROR_DB_PATH_INVALID: c_int = 6
comptime KPEP_CONFIG_ERROR_DB_NOT_FOUND: c_int = 7
comptime KPEP_CONFIG_ERROR_DB_ARCH_UNSUPPORTED: c_int = 8
comptime KPEP_CONFIG_ERROR_DB_VERSION_UNSUPPORTED: c_int = 9
comptime KPEP_CONFIG_ERROR_DB_CORRUPT: c_int = 10
comptime KPEP_CONFIG_ERROR_EVENT_NOT_FOUND: c_int = 11
comptime KPEP_CONFIG_ERROR_CONFLICTING_EVENTS: c_int = 12
comptime KPEP_CONFIG_ERROR_COUNTERS_NOT_FORCED: c_int = 13
comptime KPEP_CONFIG_ERROR_EVENT_UNAVAILABLE: c_int = 14
comptime KPEP_CONFIG_ERROR_ERRNO: c_int = 15
comptime KPEP_CONFIG_ERROR_MAX: c_int = 16


def kpep_config_error_desc(code: c_int) -> String:
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
# Library Handle
# ===-----------------------------------------------------------------------===#


struct _KPEPDataHandle(Movable):
    var dylib: OwnedDLHandle
    var symbols: _KPEPSymbols

    def __init__(out self) raises:
        self.dylib = OwnedDLHandle(
            "/System/Library/PrivateFrameworks/kperfdata.framework/kperfdata"
        )
        self.symbols = _KPEPSymbols(self.dylib)


def _init_library() -> _KPEPDataHandle:
    try:
        return _KPEPDataHandle()
    except:
        abort("failed to dynamically link to the `kperfdata` framework")


comptime _KPEP_DATA_LIBRARY = _Global["KPEP_DATA_LIBRARY", _init_library]
"""Global handle for the kperfdata library."""


@always_inline
def _sym() -> UnsafePointer[_KPEPSymbols, ImmutUntrackedOrigin]:
    try:
        return UnsafePointer(
            to=_KPEP_DATA_LIBRARY.get_or_create_ptr()[].symbols
        )
    except e:
        abort(t"kperfdata library unavailable: {e}")


# ===----------------------------------------------------------------------===#
# KPEP config functions
# ===----------------------------------------------------------------------===#


@always_inline
def kpep_config_create[
    origin: MutOrigin, //
](
    db: KPEPDb.MutPointerType,
    cfg_ptr: UnsafePointer[
        OptionalUnsafePointer[KPEPConfig, MutUntrackedOrigin], origin
    ],
) -> c_int:
    """Creates a new configuration builder for a database.

    Args:
        db: Database handle previously obtained from `kpep_db_create`.
        cfg_ptr: Pointer to receive the newly allocated config. Free it with
            `kpep_config_free`.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_create(
        db,
        cfg_ptr.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_config_free(cfg: KPEPConfig.MutPointerType):
    """Frees a config previously allocated by `kpep_config_create`."""
    _sym()[].kpep_config_free(cfg)


@always_inline
def kpep_config_add_event[
    origin_event: MutOrigin, origin_error: MutOrigin
](
    cfg: KPEPConfig.MutPointerType,
    ev_ptr: UnsafePointer[KPEPEvent.MutPointerType, origin_event],
    flag: UInt32,
    err: OptionalUnsafePointer[UInt32, origin_error],
) -> c_int:
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
    return _sym()[].kpep_config_add_event(
        cfg,
        ev_ptr.unsafe_origin_cast[MutUntrackedOrigin](),
        flag,
        cast_optional_mut_ptr[MutUntrackedOrigin](err),
    )


@always_inline
def kpep_config_remove_event(
    cfg: KPEPConfig.MutPointerType, idx: c_size_t
) -> c_int:
    """Removes the event at `idx` from a configuration.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_remove_event(cfg, idx)


@always_inline
def kpep_config_force_counters(cfg: KPEPConfig.MutPointerType) -> c_int:
    """Marks a configuration as needing force-acquired counters.

    After calling this, `kpep_config_kpc` produces register values that require
    `kpc_force_all_ctrs_set(1)` to have been called first.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_force_counters(cfg)


@always_inline
def kpep_config_events_count[
    origin: MutOrigin, //
](
    cfg: KPEPConfig.MutPointerType,
    count: UnsafePointer[c_size_t, origin],
) -> c_int:
    """Gets the number of events added to a config.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_events_count(
        cfg,
        count.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_config_events[
    origin: MutOrigin, //
](
    cfg: KPEPConfig.MutPointerType,
    buf: UnsafePointer[KPEPEvent.MutPointerType, origin],
    buf_size: c_size_t,
) -> c_int:
    """Gets all event pointers from a configuration.

    Args:
        cfg: Config to query.
        buf: Buffer to receive event pointers.
        buf_size: Buffer size in bytes; should be at least
            `kpep_config_events_count() * size_of[KPEPEvent.MutPointerType]()`.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_events(
        cfg,
        buf.unsafe_origin_cast[MutUntrackedOrigin](),
        buf_size,
    )


@always_inline
def kpep_config_kpc[
    origin: MutOrigin, //
](
    cfg: KPEPConfig.MutPointerType,
    buf: UnsafePointer[KPCConfig, origin],
    buf_size: c_size_t,
) -> c_int:
    """Gets KPC register configuration values.

    Args:
        cfg: Config to query.
        buf: Buffer to receive register config values.
        buf_size: Buffer size in bytes; should be at least
            `kpep_config_kpc_count() * size_of[KPCConfig]()`.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_kpc(
        cfg,
        buf.unsafe_origin_cast[MutUntrackedOrigin](),
        buf_size,
    )


@always_inline
def kpep_config_kpc_count[
    origin: MutOrigin, //
](
    cfg: KPEPConfig.MutPointerType,
    count: UnsafePointer[c_size_t, origin],
) -> c_int:
    """Gets the number of KPC register config values.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_kpc_count(
        cfg,
        count.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_config_kpc_classes[
    origin: MutOrigin, //
](
    cfg: KPEPConfig.MutPointerType,
    classes_ptr: UnsafePointer[UInt32, origin],
) -> c_int:
    """Gets the active KPC counter class mask.

    `classes_ptr` receives a combination of `KPC_CLASS_*_MASK` constants.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_kpc_classes(
        cfg,
        classes_ptr.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_config_kpc_map[
    origin: MutOrigin, //
](
    cfg: KPEPConfig.MutPointerType,
    buf: UnsafePointer[c_size_t, origin],
    buf_size: c_size_t,
) -> c_int:
    """Gets the mapping from event index to hardware counter slot.

    Args:
        cfg: Config to query.
        buf: Buffer to receive one hardware counter slot index per event.
        buf_size: Buffer size in bytes; should be at least
            `kpep_config_events_count() * size_of[c_size_t]()`.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_config_kpc_map(
        cfg,
        buf.unsafe_origin_cast[MutUntrackedOrigin](),
        buf_size,
    )


# ===----------------------------------------------------------------------===#
# KPEP database functions
# ===----------------------------------------------------------------------===#


@always_inline
def kpep_db_create[
    origin: MutOrigin, //
](
    name: ConstCStringPointer,
    db_ptr: UnsafePointer[KPEPDb.MutPointerType, origin],
) -> c_int:
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
    return _sym()[].kpep_db_create(
        name,
        db_ptr.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_db_free(db: KPEPDb.MutPointerType):
    """Frees a database previously allocated by `kpep_db_create`."""
    _sym()[].kpep_db_free(db)


@always_inline
def kpep_db_name[
    origin: MutOrigin, //
](
    db: KPEPDb.MutPointerType,
    name: UnsafePointer[ConstCStringPointer, origin],
) -> c_int:
    """Gets a database's marketing name, such as `"Apple M1"`.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_db_name(
        db,
        name.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_db_aliases_count[
    origin: MutOrigin, //
](db: KPEPDb.MutPointerType, count: UnsafePointer[c_size_t, origin],) -> c_int:
    """Gets the number of event aliases in a database.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_db_aliases_count(
        db,
        count.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_db_aliases[
    origin: MutOrigin, //
](
    db: KPEPDb.MutPointerType,
    buf: UnsafePointer[ConstCStringPointer, origin],
    buf_size: c_size_t,
) -> c_int:
    """Gets all alias strings from a database.

    Args:
        db: Database to query.
        buf: Buffer to receive alias string pointers.
        buf_size: Buffer size in bytes; should be at least
            `kpep_db_aliases_count() * size_of[ConstCStringPointer]()`.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_db_aliases(
        db,
        buf.unsafe_origin_cast[MutUntrackedOrigin](),
        buf_size,
    )


@always_inline
def kpep_db_counters_count[
    origin: MutOrigin, //
](
    db: KPEPDb.MutPointerType,
    classes: UInt8,
    count: UnsafePointer[c_size_t, origin],
) -> c_int:
    """Gets the number of counters for a class mask.

    `classes` is 1 for fixed, 2 for configurable, or 3 for both.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_db_counters_count(
        db,
        classes,
        count.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_db_events_count[
    origin: MutOrigin, //
](db: KPEPDb.MutPointerType, count: UnsafePointer[c_size_t, origin],) -> c_int:
    """Gets the total number of events in a database.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_db_events_count(
        db,
        count.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_db_events[
    origin: MutOrigin, //
](
    db: KPEPDb.MutPointerType,
    buf: UnsafePointer[KPEPEvent.MutPointerType, origin],
    buf_size: c_size_t,
) -> c_int:
    """Gets all event pointers from a database.

    Args:
        db: Database to query.
        buf: Buffer to receive event pointers.
        buf_size: Buffer size in bytes; should be at least
            `kpep_db_events_count() * size_of[KPEPEvent.MutPointerType]()`.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_db_events(
        db,
        buf.unsafe_origin_cast[MutUntrackedOrigin](),
        buf_size,
    )


@always_inline
def kpep_db_event[
    name_origin: ImmutOrigin, ev_origin: MutOrigin, //
](
    db: KPEPDb.MutPointerType,
    name: UnsafePointer[c_char, name_origin],
    ev_ptr: UnsafePointer[
        OptionalUnsafePointer[KPEPEvent, MutUntrackedOrigin], ev_origin
    ],
) -> c_int:
    """Looks up one event by name or alias.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_db_event(
        db,
        name.unsafe_origin_cast[ImmutUntrackedOrigin](),
        ev_ptr.unsafe_origin_cast[MutUntrackedOrigin](),
    )


# ===----------------------------------------------------------------------===#
# KPEP event functions
# ===----------------------------------------------------------------------===#


@always_inline
def kpep_event_name[
    origin: MutOrigin, //
](
    ev: KPEPEvent.MutPointerType,
    name: UnsafePointer[ConstCStringPointer, origin],
) -> c_int:
    """Gets an event's unique name, such as `"INST_ALL"`.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_event_name(
        ev,
        name.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_event_alias[
    origin: MutOrigin, //
](
    ev: KPEPEvent.MutPointerType,
    event_alias: UnsafePointer[ConstCStringPointer, origin],
) -> c_int:
    """Gets an event's alias, such as `"Instructions"`, if one exists.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_event_alias(
        ev,
        event_alias.unsafe_origin_cast[MutUntrackedOrigin](),
    )


@always_inline
def kpep_event_description[
    origin: MutOrigin, //
](
    ev: KPEPEvent.MutPointerType,
    description: UnsafePointer[ConstCStringPointer, origin],
) -> c_int:
    """Gets an event's human-readable description, if available.

    Returns:
        0 for success.
    """
    return _sym()[].kpep_event_description(
        ev,
        description.unsafe_origin_cast[MutUntrackedOrigin](),
    )


# ===-----------------------------------------------------------------------===#
# Function pointer types for KPEPConfig
# ===-----------------------------------------------------------------------===#

comptime KPEPConfigCreateFn = def(
    KPEPDb.MutPointerType,
    UnsafePointer[
        OptionalUnsafePointer[KPEPConfig, MutUntrackedOrigin],
        MutUntrackedOrigin,
    ],
) thin abi("C") -> c_int
comptime KPEPConfigFreeFn = def(KPEPConfig.MutPointerType) thin abi(
    "C"
) -> NoneType
comptime KPEPConfigAddEventFn = def(
    KPEPConfig.MutPointerType,
    UnsafePointer[KPEPEvent.MutPointerType, MutUntrackedOrigin],
    UInt32,
    OptionalUnsafePointer[UInt32, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPConfigRemoveEventFn = def(
    KPEPConfig.MutPointerType, c_size_t
) thin abi("C") -> c_int
comptime KPEPConfigForceCountersFn = def(KPEPConfig.MutPointerType) thin abi(
    "C"
) -> c_int
comptime KPEPConfigEventsCountFn = def(
    KPEPConfig.MutPointerType,
    UnsafePointer[c_size_t, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPConfigEventsFn = def(
    KPEPConfig.MutPointerType,
    UnsafePointer[KPEPEvent.MutPointerType, MutUntrackedOrigin],
    c_size_t,
) thin abi("C") -> c_int
comptime KPEPConfigKPCFn = def(
    KPEPConfig.MutPointerType,
    UnsafePointer[KPCConfig, MutUntrackedOrigin],
    c_size_t,
) thin abi("C") -> c_int
comptime KPEPConfigKPCCountFn = def(
    KPEPConfig.MutPointerType,
    UnsafePointer[c_size_t, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPConfigKPCClassesFn = def(
    KPEPConfig.MutPointerType,
    UnsafePointer[UInt32, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPConfigKPCMapFn = def(
    KPEPConfig.MutPointerType,
    UnsafePointer[c_size_t, MutUntrackedOrigin],
    c_size_t,
) thin abi("C") -> c_int

# ===-----------------------------------------------------------------------===#
# Function pointer types for KPEPDb
# ===-----------------------------------------------------------------------===#

comptime KPEPDbCreateFn = def(
    ConstCStringPointer,
    UnsafePointer[KPEPDb.MutPointerType, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPDbFreeFn = def(KPEPDb.MutPointerType) thin abi("C") -> NoneType
comptime KPEPDbNameFn = def(
    KPEPDb.MutPointerType,
    UnsafePointer[ConstCStringPointer, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPDbAliasesCountFn = def(
    KPEPDb.MutPointerType,
    UnsafePointer[c_size_t, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPDbAliasesFn = def(
    KPEPDb.MutPointerType,
    UnsafePointer[ConstCStringPointer, MutUntrackedOrigin],
    c_size_t,
) thin abi("C") -> c_int
comptime KPEPDbCountersCountFn = def(
    KPEPDb.MutPointerType,
    UInt8,
    UnsafePointer[c_size_t, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPDbEventsCountFn = def(
    KPEPDb.MutPointerType,
    UnsafePointer[c_size_t, MutUntrackedOrigin],
) thin abi("C") -> c_int
comptime KPEPDbEventsFn = def(
    KPEPDb.MutPointerType,
    UnsafePointer[KPEPEvent.MutPointerType, MutUntrackedOrigin],
    c_size_t,
) thin abi("C") -> c_int
comptime KPEPDbEventFn = def(
    KPEPDb.MutPointerType,
    UnsafePointer[c_char, ImmutUntrackedOrigin],
    UnsafePointer[
        OptionalUnsafePointer[KPEPEvent, MutUntrackedOrigin], MutUntrackedOrigin
    ],
) thin abi("C") -> c_int
comptime KPEPEventStringFn = def(
    KPEPEvent.MutPointerType,
    UnsafePointer[ConstCStringPointer, MutUntrackedOrigin],
) thin abi("C") -> c_int


# ===-----------------------------------------------------------------------===#
# KPEP Symbols
# ===-----------------------------------------------------------------------===#


struct _KPEPSymbols(Copyable):
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
    var kpep_config_free: KPEPConfigFreeFn
    var kpep_config_add_event: KPEPConfigAddEventFn
    var kpep_config_remove_event: KPEPConfigRemoveEventFn
    var kpep_config_force_counters: KPEPConfigForceCountersFn
    var kpep_config_events_count: KPEPConfigEventsCountFn
    var kpep_config_events: KPEPConfigEventsFn
    var kpep_config_kpc: KPEPConfigKPCFn
    var kpep_config_kpc_count: KPEPConfigKPCCountFn
    var kpep_config_kpc_classes: KPEPConfigKPCClassesFn
    var kpep_config_kpc_map: KPEPConfigKPCMapFn
    var kpep_db_create: KPEPDbCreateFn
    var kpep_db_free: KPEPDbFreeFn
    var kpep_db_name: KPEPDbNameFn
    var kpep_db_aliases_count: KPEPDbAliasesCountFn
    var kpep_db_aliases: KPEPDbAliasesFn
    var kpep_db_counters_count: KPEPDbCountersCountFn
    var kpep_db_events_count: KPEPDbEventsCountFn
    var kpep_db_events: KPEPDbEventsFn
    var kpep_db_event: KPEPDbEventFn
    var kpep_event_name: KPEPEventStringFn
    var kpep_event_alias: KPEPEventStringFn
    var kpep_event_description: KPEPEventStringFn

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
