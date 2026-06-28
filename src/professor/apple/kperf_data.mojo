from std.ffi import CStringSlice, c_char, c_size_t
from std.sys import size_of

from professor.ffi_utils import (
    ConstCStringPointer,
    cstr_to_slice,
    cstr_to_slice_opt,
)

from .ffi.kperf_data import (
    KPEPConfig,
    KPEPDb,
    KPEPEvent,
    kpep_config_add_event,
    kpep_config_create,
    kpep_config_events,
    kpep_config_events_count,
    kpep_config_force_counters,
    kpep_config_free,
    kpep_config_remove_event,
    kpep_db_aliases_count,
    kpep_db_create,
    kpep_db_event,
    kpep_db_events_count,
    kpep_db_free,
    kpep_db_name,
    kpep_event_alias,
    kpep_event_description,
    kpep_event_name,
)
from .events import KnownEvent
from .cpu import Cpu

# ===--------------------------------------------------------------------------------===
# Architecture enum
# ===--------------------------------------------------------------------------------===


@fieldwise_init
struct Architecture(
    Equatable,
    RegisterPassable,
    Writable,
):
    var _inner: UInt32

    comptime I386 = Self(0)
    comptime X86_64 = Self(1)
    comptime Arm = Self(2)
    comptime Arm64 = Self(3)

    def write_to(self, mut writer: Some[Writer]):
        if self._inner == Self.I386._inner:
            writer.write("i386")
        elif self._inner == Self.X86_64._inner:
            writer.write("x86_64")
        elif self._inner == Self.Arm._inner:
            writer.write("arm")
        elif self._inner == Self.Arm64._inner:
            writer.write("arm64")
        else:
            writer.write(t"unknown({self._inner})")


# ===--------------------------------------------------------------------------------===
# Database
# ===--------------------------------------------------------------------------------===


struct Database(Movable):
    """KPEP Database.

    Owns a `kpep_db` handle created by `kpep_db_create` and frees it via
    `kpep_db_free` on destruction. Not `Copyable`: the underlying handle must
    be freed exactly once.
    """

    var _ptr: UnsafePointer[KPEPDb, MutUntrackedOrigin]

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    def __init__(out self) raises:
        # SAFETY: `ptr` is scratch storage for the C "out parameter" below.
        # It is never read before `kpep_db_create` writes the real address
        # into it, and we only commit it to `self._ptr` after checking the
        # call succeeded.
        var ptr = UnsafePointer[KPEPDb, MutUntrackedOrigin].unsafe_dangling()
        if kpep_db_create({}, UnsafePointer(to=ptr)) != 0:
            raise Error("failed to create database")
        self._ptr = ptr

    def __del__(deinit self):
        kpep_db_free(self._ptr)

    # ===--------------------------------------------------------------------===
    # Public API
    # ===--------------------------------------------------------------------===

    def name(self) -> StringSlice[origin_of(self)]:
        """Returns the database's internal identifier, e.g. `"haswell"`.

        There is no `kpep_db_*` getter for this field, so this reads
        `KPEPDb.name` directly.

        Returns:
            The name of the database.
        """
        return cstr_to_slice[origin_of(self)](self._ptr[].name)

    def marketing_name(self) raises -> StringSlice[origin_of(self)]:
        """Returns the marketing name of the CPU, e.g. `"Apple M1"`."""
        var ptr: ConstCStringPointer = {}
        if kpep_db_name(self._ptr, UnsafePointer(to=ptr)) != 0:
            raise Error("failed to get marketing name")
        return cstr_to_slice[origin_of(self)](ptr)

    def cpu(self) -> Optional[Cpu]:
        """Identifies this database's Apple Silicon generation.

        Returns:
            The matching `Cpu`, or `None` if `name()` is not a recognized
            Apple Silicon generation.
        """
        return Cpu.from_db_name(self.name())

    def get_event(self, event: KnownEvent) raises -> Event[origin_of(self)]:
        """Looks up one event by its chip-agnostic identifier.

        Resolving `event` for this database's `Cpu` always yields a known,
        compile-time string literal, so the lookup never depends on a
        caller-supplied string and its null-termination.

        Args:
            event: The event to look up.

        Returns:
            The matching event.

        Raises:
            If this database's CPU generation is unrecognized, or `event` is
            unavailable on it.
        """
        var cpu = self.cpu()
        if not cpu:
            raise Error("unrecognized CPU generation: " + String(self.name()))
        var resolved = event.on(cpu.value())
        if not resolved:
            raise Error("event unavailable on this CPU generation")
        var name = resolved.value().name()

        var ev: OptionalUnsafePointer[KPEPEvent, MutUntrackedOrigin] = {}
        if (
            kpep_db_event(
                self._ptr,
                name.unsafe_ptr().bitcast[c_char](),
                UnsafePointer(to=ev),
            )
            != 0
        ):
            raise Error("event not found: " + String(name))
        if not ev:
            raise Error("event lookup returned null: " + String(name))
        return Event[origin_of(self)](ev.value())

    def events(self) raises -> List[Event[origin_of(self)]]:
        """Returns every event in the database."""
        var count: c_size_t = 0
        if kpep_db_events_count(self._ptr, UnsafePointer(to=count)) != 0:
            raise Error("failed to get event count")

        if not self._ptr[].event_arr:
            raise Error("database event array is null")

        # `kpep_db_events` does not round-trip reliably through Mojo's
        # pointer-buffer FFI here; the contiguous `event_arr` layout is checked
        # against framework getters in `tests/apple/test_kperf_layout.mojo`.
        var result = List[Event[origin_of(self)]](capacity=Int(count))
        var base = self._ptr[].event_arr.value()
        for i in range(Int(count)):
            result.append(Event[origin_of(self)](base + i))
        return result^

    def event_count(self) raises -> Int:
        var count: c_size_t = 0
        if kpep_db_events_count(self._ptr, UnsafePointer(to=count)) != 0:
            raise Error("failed to get event count")
        return Int(count)

    def alias_count(self) raises -> Int:
        var count: c_size_t = 0
        if kpep_db_aliases_count(self._ptr, UnsafePointer(to=count)) != 0:
            raise Error("failed to get alias count")
        return Int(count)

    def architecture(self) -> Architecture:
        # No `kpep_db_*` getter exposes this; read the field directly.
        return Architecture(self._ptr[].architecture)


# ===--------------------------------------------------------------------------------===
# Event
# ===--------------------------------------------------------------------------------===


struct Event[origin: ImmutOrigin](Copyable, ImplicitlyCopyable, Movable):
    """A borrowed, non-owning view of one event entry.

    `Event` never allocates or frees memory: the `KPEPEvent` it points to is
    owned by the `Database` (or `Config`) that produced it. `origin` ties an
    `Event`'s lifetime to that owner, so it cannot be returned or stored past
    the point where the owner is destroyed.
    """

    var _ptr: UnsafePointer[KPEPEvent, MutUntrackedOrigin]

    def __init__(out self, ptr: UnsafePointer[KPEPEvent, MutUntrackedOrigin]):
        self._ptr = ptr

    def name(self) raises -> StringSlice[Self.origin]:
        """Unique name of the event, such as `"INST_RETIRED.ANY"`."""
        var ptr: ConstCStringPointer = {}
        if kpep_event_name(self._ptr, UnsafePointer(to=ptr)) != 0:
            raise Error("failed to get event name")
        return cstr_to_slice[Self.origin](ptr)

    def alias(self) raises -> Optional[StringSlice[Self.origin]]:
        """Alias name, such as `"Instructions"`, `"Cycles"`, if any."""
        var ptr: ConstCStringPointer = {}
        if kpep_event_alias(self._ptr, UnsafePointer(to=ptr)) != 0:
            raise Error("failed to get event alias")
        return cstr_to_slice_opt[Self.origin](ptr)

    def description(self) raises -> Optional[StringSlice[Self.origin]]:
        """Human-readable description, if available."""
        var ptr: ConstCStringPointer = {}
        if kpep_event_description(self._ptr, UnsafePointer(to=ptr)) != 0:
            raise Error("failed to get event description")
        return cstr_to_slice_opt[Self.origin](ptr)

    def is_fixed(self) -> Bool:
        """Whether this event must be placed in a fixed counter slot."""
        # No `kpep_event_*` getter exposes this; read the field directly.
        return self._ptr[].is_fixed != 0

    def number(self) -> UInt8:
        """Event number (selector value written to the PMC config register)."""
        # No `kpep_event_*` getter exposes this; read the field directly.
        return self._ptr[].number

    def mask(self) -> UInt32:
        """Hardware event selector mask."""
        # No `kpep_event_*` getter exposes this; read the field directly.
        return self._ptr[].mask


# ===--------------------------------------------------------------------------------===
# Configuration
# ===--------------------------------------------------------------------------------===


struct Config[origin: ImmutOrigin](Movable):
    """A mutable KPC configuration builder.

    Owns a `kpep_config` handle created by `kpep_config_create` and frees it
    via `kpep_config_free` on destruction. `origin` ties a `Config`'s
    lifetime to the `Database` it was built from, since the underlying
    `kpep_config` keeps a pointer back into that database.
    """

    var _ptr: UnsafePointer[KPEPConfig, MutUntrackedOrigin]

    def __init__(out self, ref[Self.origin] db: Database) raises:
        # SAFETY: see `Database.__init__`; same scratch-then-commit pattern.
        var ptr: OptionalUnsafePointer[KPEPConfig, MutUntrackedOrigin] = {}
        if kpep_config_create(db._ptr, UnsafePointer(to=ptr)) != 0:
            raise Error("failed to create config")
        if not ptr:
            raise Error("config creation returned null")
        self._ptr = ptr.value()

    def __del__(deinit self):
        kpep_config_free(self._ptr)

    def add_event(mut self, var event: Event[Self.origin]) raises:
        """Adds an event to this configuration, counting in all modes.

        Raises:
            If the event could not be added (e.g. conflicts with one already
            added, or counters were exhausted).
        """
        var err: UInt32 = 0
        if (
            kpep_config_add_event(
                self._ptr,
                UnsafePointer(to=event._ptr),
                0,
                UnsafePointer(to=err),
            )
            != 0
        ):
            raise Error(
                "failed to add event (conflicting event bitmap: "
                + String(err)
                + ")"
            )

    def remove_event(mut self, idx: Int) raises:
        if kpep_config_remove_event(self._ptr, c_size_t(idx)) != 0:
            raise Error("failed to remove event at index " + String(idx))

    def force_counters(mut self) raises:
        """Marks this configuration as needing force-acquired counters."""
        if kpep_config_force_counters(self._ptr) != 0:
            raise Error("failed to force counters")

    def events_count(self) raises -> Int:
        var count: c_size_t = 0
        if kpep_config_events_count(self._ptr, UnsafePointer(to=count)) != 0:
            raise Error("failed to get event count")
        return Int(count)

    def events(self) raises -> List[Event[Self.origin]]:
        """Returns every event added to this configuration."""
        var count = self.events_count()
        var buf = List[UnsafePointer[KPEPEvent, MutUntrackedOrigin]](
            length=count,
            fill=UnsafePointer[KPEPEvent, MutUntrackedOrigin].unsafe_dangling(),
        )
        if (
            kpep_config_events(
                self._ptr,
                buf.unsafe_ptr(),
                c_size_t(count)
                * c_size_t(
                    size_of[UnsafePointer[KPEPEvent, MutUntrackedOrigin]]()
                ),
            )
            != 0
        ):
            raise Error("failed to get events")

        var result = List[Event[Self.origin]](capacity=count)
        for i in range(count):
            result.append(Event[Self.origin](buf[i]))
        return result^
