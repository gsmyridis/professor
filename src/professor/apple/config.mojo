from std.ffi import c_size_t
from std.sys import size_of

from .ffi.kperf_data import (
    KPEPConfig,
    KPEPEvent,
    KPCConfig,
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

# ===-----------------------------------------------------------------------===
# KPC Configuration
# ===-----------------------------------------------------------------------===

comptime CounterConfig = KPCConfig
"""A raw KPC counter configuration word.

This is the `UInt64` value produced by `kperfdata` and passed to
`kpc_set_config`. It programs hardware counter configuration registers; it is
not a counter value read back from the PMU.
"""

# TODO: Use error descriptions from ffi when raising

# ===-----------------------------------------------------------------------===
# Count mode
# ===-----------------------------------------------------------------------===


struct CountMode(RegisterPassable):
    """Controls which execution modes contribute to an event's count.

    This flag is passed while adding an event to a `ConfigBuilder`. It affects
    how `kperfdata` computes the counter configuration words for that event.
    """

    comptime AllModes = Self(unsafe_flag=0)
    """Counts event in all modes e.g. userspace, kernel, etc."""

    comptime Userspace = Self(unsafe_flag=1)
    """Counts event only for userspace code."""

    var _flag: UInt32

    def __init__(out self, *, unsafe_flag: UInt32):
        self._flag = unsafe_flag


# ===-----------------------------------------------------------------------===
# KPEP Configuration
# ===-----------------------------------------------------------------------===

struct Configuration(Movable):
    """Owned runtime plan for programming and reading KPC counters.

    This is the safe-layer snapshot produced from a temporary `ConfigBuilder`.
    It contains only the copied values needed by samplers: the active counter
    classes, raw counter configuration words, the mapping from requested events
    to hardware counter slots, event names, and the number of raw counter values
    to read.

    It deliberately does not own a `KPEPConfig` or `Database`; those are only
    needed while translating human-readable events into KPC data.
    """

    var classes: Classes
    """Counter classes that must be enabled for this configuration."""

    var registers: List[CounterConfig]
    """Raw KPC counter configuration words passed to `kpc_set_config`."""

    var counter_map: List[Int]
    """Maps event order to hardware counter slot indices.

    Samplers read raw counter values in hardware slot order, then use this map
    to return values in the same order as the events added to the builder.
    """

    var event_names: List[String]
    """Names of the configured events, in event order."""

    var hardware_counter_count: Int
    """Number of raw hardware counter values the sampler must read."""

    def __init__(
        out self,
        *,
        var classes: Classes,
        var registers: List[CounterConfig],
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
    """Mutable KPEP-backed builder for a runtime `Configuration`.

    This struct owns a `KPEPConfig` handle created by `kpep_config_create`.
    The handle belongs to Apple's `kperfdata` layer and translates database
    event descriptors into KPC counter classes, counter configuration words,
    and event-to-counter-slot mappings.

    `origin` ties the builder's lifetime to the `Database` it was built from,
    because the underlying `KPEPConfig` stores pointers into that database.
    Call `build()` to copy out the runtime values and discard the KPEP handle.
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

    def add_event(
        mut self,
        var event: EventDescriptor[Self.origin],
        *,
        mode: CountMode = CountMode.Userspace,
    ) raises:
        """Adds an event to this configuration.

        Defaults to userspace-only counting. Pass `CountMode.AllModes` to count
        both userspace and kernel/system execution attributed to the thread.

        Raises:
            If the event could not be added (e.g. conflicts with one already
            added, or counters were exhausted).
        """
        var err: UInt32 = 0
        if (
            kpep_config_add_event(
                self._ptr,
                UnsafePointer(to=event._ptr),
                mode._flag,
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

    def counters(self) raises -> List[CounterConfig]:
        """Gets the raw KPC counter configuration words."""
        var count = self.counter_count()
        var buf = List[CounterConfig](length=count, fill=0)
        var res = kpep_config_kpc(
            self._ptr,
            buf.unsafe_ptr(),
            c_size_t(count * size_of[CounterConfig]()),
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

        return Classes(unsafe_mask=classes)

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

        var hardware_counter_count = Int(get_counter_count(classes.value()))
        return Configuration(
            classes=classes^,
            registers=registers^,
            counter_map=counter_map^,
            event_names=event_names^,
            hardware_counter_count=hardware_counter_count,
        )
