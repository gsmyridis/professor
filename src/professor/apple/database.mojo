from std.ffi import c_size_t, c_char, CStringSlice
from std.sys import size_of

from .ffi.kperf_data import (
    KPEPDb,
    KPEPEvent,
    kpep_db_create,
    kpep_db_free,
    kpep_db_name,
    kpep_db_events_count,
    kpep_db_aliases_count,
    kpep_db_event,
    kpep_db_aliases,
    kpep_db_counters_count,
)
from .cpu import Cpu, Architecture
from .event import Event, EventDescriptor
from .classes import Classes

from professor.ffi_utils import (
    ConstCStringPointer,
    cstr_to_slice,
    cstr_to_string,
)


struct Database(Movable):
    """KPEP Database.

    Owns a `kpep_db` handle created by `kpep_db_create` and frees it via
    `kpep_db_free` on destruction. Not `Copyable`: the underlying handle must
    be freed exactly once.
    """

    comptime UnsafePointerType = UnsafePointer[KPEPDb, MutUntrackedOrigin]

    var _ptr: Self.UnsafePointerType

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    def __init__(out self) raises:
        var ptr = Self.UnsafePointerType.unsafe_dangling()
        if kpep_db_create({}, UnsafePointer(to=ptr)) != 0:
            raise Error("failed to create database")

        return self.__init__(unsafe_ptr=ptr)

    @always_inline
    def __init__(out self, *, unsafe_ptr: Self.UnsafePointerType):
        self._ptr = unsafe_ptr

    def __del__(deinit self):
        kpep_db_free(self._ptr)

    @always_inline
    def unsafe_ptr(self) -> Self.UnsafePointerType:
        return self._ptr

    # ===--------------------------------------------------------------------===
    # Database information methods
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
    # Aliases methods
    # ===--------------------------------------------------------------------===

    def alias_count(self) raises -> Int:
        """Gets the number of event aliases in the database.

        Returns:
            The number of event aliases.
        """
        var count: c_size_t = 0
        if kpep_db_aliases_count(self._ptr, UnsafePointer(to=count)) != 0:
            raise Error("failed to get alias count")
        return Int(count)

    def aliases(self) raises -> List[String]:
        """Returns the alias names for events that are available
        in the database.

        Returns:
            A list of event alias names.
        """
        var count = self.alias_count()
        var buf = List[ConstCStringPointer](
            length=count, fill=ConstCStringPointer(None)
        )
        var res = kpep_db_aliases(
            self._ptr,
            buf.unsafe_ptr(),
            c_size_t(count * size_of[ConstCStringPointer]()),
        )

        if res != 0:
            raise Error("failed to get event aliases")

        var aliases = List[String](length=count, fill="")
        for i in range(count):
            aliases[i] = cstr_to_string(buf[i])

        return aliases^

    # ===--------------------------------------------------------------------===
    # Event methods
    # ===--------------------------------------------------------------------===

    def event_count(self) raises -> Int:
        """Get the number of events in the database.

        Returns:
            The number of events.
        """
        var count: c_size_t = 0
        if kpep_db_events_count(self._ptr, UnsafePointer(to=count)) != 0:
            raise Error("failed to get event count")
        return Int(count)

    def events(self) raises -> List[EventDescriptor[origin_of(self)]]:
        """Returns every event definition in the database.

        Returns:
            A list with the event handles.
        """
        var count: c_size_t = 0
        if kpep_db_events_count(self._ptr, UnsafePointer(to=count)) != 0:
            raise Error("failed to get event count")

        if not self._ptr[].event_arr:
            raise Error("database event array is null")

        # `kpep_db_events` does not round-trip reliably through Mojo's
        # pointer-buffer FFI here; the contiguous `event_arr` layout is checked
        # against framework getters in `tests/apple/test_kperf_layout.mojo`.
        var result = List[EventDescriptor[origin_of(self)]](capacity=Int(count))
        var base = self._ptr[].event_arr.value()
        for i in range(Int(count)):
            result.append(EventDescriptor[origin_of(self)](unsafe_ptr=base + i))
        return result^

    def get_event[
        origin: ImmutOrigin
    ](self, *, unsafe_name: CStringSlice[origin]) raises -> EventDescriptor[
        origin_of(self)
    ]:
        """Looks up an event by a null-terminated name or alias.

        Args:
            unsafe_name: Null-terminated event name or alias.

        Returns:
            The event.

        Raises:
            When the event is not contained in the database.
        """
        var ev: OptionalUnsafePointer[KPEPEvent, MutUntrackedOrigin] = {}
        var res = kpep_db_event(
            self._ptr,
            unsafe_name.unsafe_ptr().bitcast[c_char](),
            UnsafePointer(to=ev),
        )
        if res != 0:
            raise Error("event not found: " + String(unsafe_name))
        if not ev:
            raise Error("event lookup returned null: " + String(unsafe_name))
        return EventDescriptor[origin_of(self)](unsafe_ptr=ev.value())

    def get_event(
        self, event: Some[Event]
    ) raises -> EventDescriptor[origin_of(self)]:
        """Looks up an event by its typed identifier.

        Args:
            event: The event to look up.

        Returns:
            The matching event.

        Raises:
            If `event` is not contained in this database (e.g. it belongs
            to a different Apple Silicon generation).
        """
        return self.get_event(unsafe_name=event.name().as_c_string_slice())

    # ===--------------------------------------------------------------------===
    # Counter methods
    # ===--------------------------------------------------------------------===

    def counters_count(self, classes: Classes) raises -> Int:
        """Gets the number of counters for a class mask.

        Args:
            classes: A class mask.

        Rerutns:
            The number of counters for the specified classes.
        """
        var count: c_size_t = 0
        var res = kpep_db_counters_count(
            self._ptr,
            UInt8(classes.value()),
            UnsafePointer(to=count),
        )
        if res != 0:
            raise Error("failed to get counters count for specified classes")

        return Int(count)
