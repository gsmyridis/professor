struct CounterToken(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """Opaque identity of a counter owned by a `Group`."""

    var _group_id: UInt64
    var _event_id: UInt64

    def __init__(out self, *, unsafe_group_id: UInt64, unsafe_event_id: UInt64):
        self._group_id = unsafe_group_id
        self._event_id = unsafe_event_id
