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
# Event
# ===--------------------------------------------------------------------------------===




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
