from .sys.kperf import (
    KPC_CLASS_FIXED_MASK,
    KPC_CLASS_CONFIGURABLE_MASK,
    KPC_CLASS_POWER_MASK,
    KPC_CLASS_RAWPMU_MASK,
)


struct Classes(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    comptime Fixed = Self(_mask=KPC_CLASS_FIXED_MASK)
    """Fixed counters: they always measure the same events."""

    comptime Configurable = Self(_mask=KPC_CLASS_CONFIGURABLE_MASK)
    """Counters that can be configured for what events to count."""

    comptime Power = Self(_mask=KPC_CLASS_POWER_MASK)
    """Counters that count power related information."""

    comptime RawPMU = Self(_mask=KPC_CLASS_RAWPMU_MASK)

    # ===--------------------------------------------------------------------===
    # Field
    # ===--------------------------------------------------------------------===

    var _mask: UInt32

    # ===--------------------------------------------------------------------===
    # Methods
    # ===--------------------------------------------------------------------===

    @doc_hidden
    def __init__(out self, *, _mask: UInt32):
        self._mask = _mask

    def __or__(self, other: Self) -> Self:
        return Self(_mask=self._mask | other._mask)

    def __contains__(self, other: Self) -> Bool:
        return (self._mask & other._mask) == other._mask

    def value(self) -> UInt32:
        """Returns the raw classes mask."""
        return self._mask
