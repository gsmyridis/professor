from std.ffi import c_size_t
from std.sys import size_of

from .ffi.kperf_data import (
    KPEPConfig,
    KPEPEvent,
    KPCConfig as _KPCConfig,
    kpep_config_create,
    kpep_config_free,
    kpep_config_add_event,
    kpep_config_remove_event,
    kpep_config_force_counters,
    kpep_config_events_count,
    kpep_config_events,
    kpep_config_kpc_count,
    kpep_config_kpc,
    kpep_config_kpc_classes,
    kpep_config_kpc_map,
    kpep_config_error_desc,
)
from .database import Database
from .event import EventDescriptor
from .classes import Classes
from .kperf import get_counter_count

# ===-----------------------------------------------------------------------====
# Configuration
# ===-----------------------------------------------------------------------====

comptime KPCConfig = _KPCConfig
# TODO: add description
# TODO: Use error descriptions from ffi when raising


struct Configuration(Movable):
    """Owned KPC configuration produced from a temporary kpep builder.

    Sampling only needs these copied values. It does not need the kpep database
    or config handle that computed them.
    """

    var classes: Classes
    var registers: List[KPCConfig]
    var counter_map: List[Int]
    var event_names: List[String]
    var hardware_counter_count: Int

    def __init__(
        out self,
        *,
        var classes: Classes,
        var registers: List[KPCConfig],
        var counter_map: List[Int],
        var event_names: List[String],
        hardware_counter_count: Int,
    ):
        self.classes = classes^
        self.registers = registers^
        self.counter_map = counter_map^
        self.event_names = event_names^
        self.hardware_counter_count = hardware_counter_count


# ===-----------------------------------------------------------------------====
# ConfigBuilder
# ===-----------------------------------------------------------------------====


struct ConfigBuilder[origin: ImmutOrigin](Movable):
    """A mutable KPC configuration builder.

    Owns a `kpep_config` handle created by `kpep_config_create` and frees it
    via `kpep_config_free` on destruction. `origin` ties a `Config`'s
    lifetime to the `Database` it was built from, since the underlying
    `kpep_config` keeps a pointer back into that database.
    """

    comptime _UnsafePointerType = UnsafePointer[KPEPConfig, MutUntrackedOrigin]

    var _ptr: Self._UnsafePointerType

    # ===--------------------------------------------------------------------===
    # Lifetime methods
    # ===--------------------------------------------------------------------===

    def __init__(out self, ref[Self.origin] db: Database) raises:
        var ptr = Self._UnsafePointerType.unsafe_dangling()
        if kpep_config_create(db._ptr, UnsafePointer(to=ptr)) != 0:
            raise Error("failed to create config")
        self._ptr = ptr

    def __del__(deinit self):
        kpep_config_free(self._ptr)

    # ===--------------------------------------------------------------------===
    # Event methods
    # ===--------------------------------------------------------------------===

    def add_event(mut self, var event: EventDescriptor[Self.origin]) raises:
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

    def events_count(self) raises -> Int:
        var count: c_size_t = 0
        if kpep_config_events_count(self._ptr, UnsafePointer(to=count)) != 0:
            raise Error("failed to get event count")
        return Int(count)

    def events(self) raises -> List[EventDescriptor[Self.origin]]:
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

        var result = List[EventDescriptor[Self.origin]](capacity=count)
        for i in range(count):
            result.append(EventDescriptor[Self.origin](unsafe_ptr=buf[i]))
        return result^

    # ===--------------------------------------------------------------------===
    # Counter methods
    # ===--------------------------------------------------------------------===

    def force_counters(mut self) raises:
        """Marks this configuration as needing force-acquired counters.

        Force-counters must be called before any add_event on Apple Silicon.
        The configuration PMCs are normally owned by powerd; this flags the
        config so the registers it produces assume you will take ownership.
        """
        if kpep_config_force_counters(self._ptr) != 0:
            raise Error("failed to force counters")

    def counter_count(self) raises -> Int:
        """Returns the number of KPC register config values.

        Returns:
            The number of KPC register config values.
        """
        var count: c_size_t = 0
        var res = kpep_config_kpc_count(
            self._ptr,
            UnsafePointer(to=count),
        )
        if res != 0:
            raise Error("failed to read the kpc register count")

        return Int(count)

    def counters(self) raises -> List[KPCConfig]:
        """Gets KPC register configuration values."""
        var count = self.counter_count()
        var buf = List[KPCConfig](length=count, fill=0)
        var res = kpep_config_kpc(
            self._ptr,
            buf.unsafe_ptr(),
            c_size_t(count * size_of[KPCConfig]()),
        )
        if res != 0:
            var error_msg = kpep_config_error_desc(res)
            raise Error(t"failed to read the kpc registers: {error_msg}")

        return buf^

    def active_classes(self) raises -> Classes:
        """Gets the active KPC counter classes mask.

        Returns:
            The classes mask.
        """
        var classes: UInt32 = 0
        var res = kpep_config_kpc_classes(self._ptr, UnsafePointer(to=classes))
        if res != 0:
            raise Error("failed to read active KPC counter classes")

        return Classes(classes)

    def counter_map(self) raises -> List[Int]:
        """Returns the event index to hardware counter slot mapping."""
        var count = self.events_count()
        var raw = List[c_size_t](length=count, fill=0)
        if count == 0:
            return List[Int]()

        var res = kpep_config_kpc_map(
            self._ptr,
            raw.unsafe_ptr(),
            c_size_t(count * size_of[c_size_t]()),
        )
        if res != 0:
            var error_msg = kpep_config_error_desc(res)
            raise Error(t"failed to read the kpc counter map: {error_msg}")

        var result = List[Int](capacity=count)
        for i in range(count):
            result.append(Int(raw[i]))
        return result^

    # ===--------------------------------------------------------------------===
    # Build configuration method
    # ===--------------------------------------------------------------------===

    def build(self) raises -> Configuration:
        """Snapshots this builder into an owned runtime configuration."""
        var classes = self.active_classes()
        var registers = self.counters()
        var counter_map = self.counter_map()
        var events = self.events()
        var event_names = List[String](capacity=len(events))
        for event in events:
            event_names.append(String(event.name()))

        var hardware_counter_count = Int(get_counter_count(classes._inner))
        return Configuration(
            classes=classes^,
            registers=registers^,
            counter_map=counter_map^,
            event_names=event_names^,
            hardware_counter_count=hardware_counter_count,
        )
