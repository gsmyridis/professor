from .ffi.kperf_data import (
    KPEPEvent,
    kpep_event_name,
    kpep_event_alias,
    kpep_event_description,
)

from professor.ffi_utils import (
    ConstCStringPointer,
    cstr_to_slice,
    cstr_to_slice_opt,
)


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
