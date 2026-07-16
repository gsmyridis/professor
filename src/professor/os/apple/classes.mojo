from .ffi.kperf import (
    KPC_CLASS_FIXED_MASK,
    KPC_CLASS_CONFIGURABLE_MASK,
    KPC_CLASS_POWER_MASK,
    KPC_CLASS_RAWPMU_MASK,
)


struct Classes(Copyable, Equatable, RegisterPassable, Writable):
    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    comptime Fixed = Self(unsafe_mask=KPC_CLASS_FIXED_MASK)
    """Fixed counters: they always measure the same events."""

    comptime Configurable = Self(unsafe_mask=KPC_CLASS_CONFIGURABLE_MASK)
    """Counters that can be configured for what events to count."""

    comptime Power = Self(unsafe_mask=KPC_CLASS_POWER_MASK)
    """Counters that count power related information."""

    comptime RawPMU = Self(unsafe_mask=KPC_CLASS_RAWPMU_MASK)

    # ===--------------------------------------------------------------------===
    # Field
    # ===--------------------------------------------------------------------===

    var _mask: UInt32

    # ===--------------------------------------------------------------------===
    # Methods
    # ===--------------------------------------------------------------------===

    def __init__(out self, *, unsafe_mask: UInt32):
        self._mask = unsafe_mask

    def __or__(self, other: Self) -> Self:
        return Self(unsafe_mask=self._mask | other._mask)

    def __and__(self, other: Self) -> Self:
        return Self(unsafe_mask=self._mask & other._mask)

    def value(self) -> UInt32:
        """Returns the raw classes mask."""
        return self._mask
