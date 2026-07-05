from .ffi.kperf import (
    KPC_CLASS_FIXED_MASK,
    KPC_CLASS_CONFIGURABLE_MASK,
    KPC_CLASS_POWER_MASK,
    KPC_CLASS_RAWPMU_MASK,
)


# TODO: Rethink the classes abstraction
@fieldwise_init
struct Classes(Copyable, Equatable, RegisterPassable, Writable):
    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    comptime Fixed = Self(KPC_CLASS_FIXED_MASK)
    """Fixed counters: they always measure the same events."""

    comptime Configurable = Self(KPC_CLASS_CONFIGURABLE_MASK)
    """Counters that can be configured for what events to count."""

    comptime Power = Self(KPC_CLASS_POWER_MASK)
    """Counters that count power related information."""

    comptime RawPMU = Self(KPC_CLASS_RAWPMU_MASK)

    # ===--------------------------------------------------------------------===
    # Field
    # ===--------------------------------------------------------------------===

    var _inner: UInt32

    # ===--------------------------------------------------------------------===
    # Methods
    # ===--------------------------------------------------------------------===

    def __or__(self, other: Self) -> Self:
        return Self(self._inner | other._inner)

    def __and__(self, other: Self) -> Self:
        return Self(self._inner & other._inner)
