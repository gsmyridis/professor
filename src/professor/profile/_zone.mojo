from std.os import abort
from std.sys.intrinsics import unlikely

from professor.measure import Instrument
from ._consts import is_profiling_enabled
from ._state import _CoreProfilerState

# ===-----------------------------------------------------------------------===
# Processed Data
# ===-----------------------------------------------------------------------===


@fieldwise_init
struct _DisabledProcessedDataHandle(ImplicitlyCopyable, RegisterPassable):
    pass


struct _ProcessedDataHandle[enabled: Bool, origin: MutOrigin](
    ImplicitlyCopyable
):
    # ===--------------------------------------------------------------------===
    # Comptime Aliases
    # ===--------------------------------------------------------------------===

    comptime _EnabledType = UnsafePointer[UInt64, Self.origin]
    comptime _DisabledType = _DisabledProcessedDataHandle
    comptime _StorageType: ImplicitlyCopyable = (
        Self._EnabledType if Self.enabled else Self._DisabledType
    )

    # ===--------------------------------------------------------------------===
    # Fields
    # ===--------------------------------------------------------------------===

    var _storage: Self._StorageType

    # ===--------------------------------------------------------------------===
    # Lifecycle methods
    # ===--------------------------------------------------------------------===

    @always_inline
    def __init__(out self, bytes: Self._EnabledType):
        comptime assert Self.enabled
        self._storage = rebind_var[Self._StorageType](bytes)

    @always_inline
    def __init__(out self):
        comptime assert not Self.enabled
        self._storage = rebind_var[Self._StorageType](Self._DisabledType())

    # ===--------------------------------------------------------------------===
    # Processed bytes methods
    # ===--------------------------------------------------------------------===

    @always_inline
    def add_bytes(self, bytes: UInt64):
        comptime if Self.enabled:
            rebind[UnsafePointer[UInt64, Self.origin]](self._storage)[] += bytes
        else:
            _ = bytes


# ===-----------------------------------------------------------------------===
# Profiling Zone
# ===-----------------------------------------------------------------------===


@fieldwise_init
@explicit_destroy("The profiling zone must be closed with: .close()")
struct _DisabledProfileZone(Movable):
    @always_inline
    def close(deinit self):
        pass


@fieldwise_init
@explicit_destroy("The profiling zone must be closed with: .close()")
struct _EnabledProfileZone[
    I: Instrument,
    C: Int,
    origin: MutOrigin,
    tracks_data: Bool,
](Movable) where (
    C > 0
):
    comptime MetricType = Self.I.MetricType

    var label: StaticString
    var anchor_index: Int
    var parent_index: Int
    var depth: Int
    var metric_inclusive_prev: Self.MetricType
    var metric_open: Self.MetricType
    var processed_bytes: UInt64
    var prof_state: UnsafePointer[
        _CoreProfilerState[Self.I, Self.C], Self.origin
    ]

    def close(deinit self):
        # Sample first so close-side bookkeeping stays out of the interval.
        var sample = self.prof_state[].instrument.measure()
        var delta = sample.sub(self.metric_open)

        if unlikely(self.prof_state[].current_open_depth != self.depth + 1):
            abort("Mismatch open and close")

        ref anchor = self.prof_state[].anchors[self.anchor_index]
        anchor.hit_count += 1
        anchor.exclusive = anchor.exclusive.add(delta)
        anchor.inclusive = self.metric_inclusive_prev.add(delta)

        if unlikely(anchor.hit_count == 1):
            anchor.inclusive_min = delta.copy()
        else:
            anchor.inclusive_min = anchor.inclusive_min.min(delta)

        comptime if Self.tracks_data:
            anchor.processed_data.value += self.processed_bytes

        # Account for recursive calls.
        self.prof_state[].current_open_depth = self.depth
        self.prof_state[].current_open_idx = self.parent_index
        ref parent = self.prof_state[].anchors[self.parent_index]
        parent.exclusive = parent.exclusive.sub(delta)

    @always_inline
    def add_bytes(mut self, bytes: UInt64) where Self.tracks_data:
        self.processed_bytes += bytes


@explicit_destroy("The profiling zone must be closed with: .close()")
struct _ProfileZone[
    I: Instrument,
    C: Int,
    origin: MutOrigin,
    tracks_data: Bool = False,
] where (
    C > 0
):
    """A zone whose workload capability is fixed in its compile-time type."""

    # ===-------------------------------------------------------------------===
    # Comptime Aliases
    # ===-------------------------------------------------------------------===

    comptime _EnabledType = _EnabledProfileZone[
        Self.I, Self.C, Self.origin, Self.tracks_data
    ]
    comptime _DisabledType = _DisabledProfileZone
    comptime _StorageType: Movable = (
        Self._EnabledType if is_profiling_enabled() else Self._DisabledType
    )

    # ===-------------------------------------------------------------------===
    # Fields
    # ===-------------------------------------------------------------------===

    var _storage: Self._StorageType

    # ===-------------------------------------------------------------------===
    # Lifecycle methods
    # ===-------------------------------------------------------------------===

    @always_inline
    def __init__(out self):
        comptime assert not is_profiling_enabled()
        self._storage = rebind_var[Self._StorageType](_DisabledProfileZone())

    @always_inline
    def __init__(out self, var enabled: Self._EnabledType):
        comptime assert is_profiling_enabled()
        self._storage = rebind_var[Self._StorageType](enabled^)

    @always_inline
    def close(deinit self):
        comptime if is_profiling_enabled():
            var enabled = rebind_var[Self._EnabledType](self._storage^)
            enabled^.close()
        else:
            var disabled = rebind_var[Self._DisabledType](self._storage^)
            disabled^.close()

    # ===-------------------------------------------------------------------===
    # Context managment
    # ===-------------------------------------------------------------------===

    @always_inline
    def __enter__(self) where not Self.tracks_data:
        pass

    @always_inline
    def __enter__[
        handle_origin: MutOrigin, //
    ](
        ref[handle_origin] self,
    ) -> _ProcessedDataHandle[
        is_profiling_enabled(), handle_origin
    ] where Self.tracks_data:
        # TODO: Make it type comptime alias?
        comptime HandleType = _ProcessedDataHandle[
            is_profiling_enabled(), handle_origin
        ]

        comptime if is_profiling_enabled():
            ref enabled = rebind[Self._EnabledType](self._storage)
            return rebind_var[HandleType](
                _ProcessedDataHandle[True, handle_origin](
                    UnsafePointer(
                        to=enabled.processed_bytes
                    ).unsafe_origin_cast[handle_origin]()
                )
            )
        else:
            return rebind_var[HandleType](
                _ProcessedDataHandle[False, handle_origin]()
            )

    @always_inline
    def __exit__(deinit self):
        self^.close()

    # ===-------------------------------------------------------------------===
    # Processed bytes methods
    # ===-------------------------------------------------------------------===

    @always_inline
    def add_bytes(mut self, bytes: UInt64) where Self.tracks_data:
        """Records bytes on a zone held directly, without a `with` handle."""
        comptime if is_profiling_enabled():
            ref enabled = rebind[Self._EnabledType](self._storage)
            enabled.add_bytes(bytes)
        else:
            _ = bytes
