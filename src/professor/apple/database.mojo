from std.ffi import c_size_t, c_char

from .ffi.kperf_data import (
    KPEPDb,
    KPEPEvent,
    kpep_db_create,
    kpep_db_free,
    kpep_db_name,
    kpep_db_events_count,
    kpep_db_aliases_count,
    kpep_db_event,
)
from .cpu import Cpu, Architecture
from .event import Event
from .events import KnownEvent

from professor.ffi_utils import cstr_to_slice, ConstCStringPointer


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
    # Database information
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

    def cpu(self) raises -> Cpu:
        """Identifies this database's Apple Silicon generation.

        Returns:
            The matching Cpu if the database name corresponds to an
            Apple Silicon generation.
        """
        return Cpu(database_name=self.name())

    def architecture(self) -> Architecture:
        """Returns the CPU architecture this database is running on."""
        return Architecture(self._ptr[].architecture)

    # ===--------------------------------------------------------------------===
    # Get event
    # ===--------------------------------------------------------------------===

    def get_event_by_name[
        origin: Origin
    ](self, name: StringSlice[origin]) raises -> Event[origin_of(self)]:
        """Looks up an event by its name.

        Args:
            name: Name of the event.

        Returns:
            The event.

        Raises:
            When the event is not contained in the database.
        """
        var ev: OptionalUnsafePointer[KPEPEvent, MutUntrackedOrigin] = {}
        var res = kpep_db_event(
            self._ptr,
            name.unsafe_ptr().bitcast[c_char](),
            UnsafePointer(to=ev),
        )
        if res != 0:
            raise Error("event not found: " + String(name))
        if not ev:
            raise Error("event lookup returned null: " + String(name))
        return Event[origin_of(self)](ev.value())

    # def get_event(self, event: KnownEvent) raises -> Event[origin_of(self)]:
    #     """Looks up one event by its chip-agnostic identifier.

    #     Resolving `event` for this database's `Cpu` always yields a known,
    #     compile-time string literal, so the lookup never depends on a
    #     caller-supplied string and its null-termination.

    #     Args:
    #         event: The event to look up.

    #     Returns:
    #         The matching event.

    #     Raises:
    #         If this database's CPU generation is unrecognized, or `event` is
    #         unavailable on it.
    #     """
    #     var cpu = self.cpu()
    #     var resolved = event.on(cpu)
    #     if not resolved:
    #         raise Error("event unavailable on this CPU generation")
    #     var name = resolved.value().name()

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
