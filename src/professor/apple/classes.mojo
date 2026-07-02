from .ffi.kperf import (
    KPC_CLASS_FIXED_MASK,
    KPC_CLASS_CONFIGURABLE_MASK,
    KPC_CLASS_POWER_MASK,
    KPC_CLASS_RAWPMU_MASK,
)


@fieldwise_init
struct Classes(Copyable, Equatable, RegisterPassable, Writable):
    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    comptime Fixed = Self(KPC_CLASS_FIXED_MASK)

    comptime Configurable = Self(KPC_CLASS_CONFIGURABLE_MASK)

    comptime Power = Self(KPC_CLASS_POWER_MASK)

    comptime RawPMU = Self(KPC_CLASS_RAWPMU_MASK)

    # ===--------------------------------------------------------------------===
    # Field
    # ===--------------------------------------------------------------------===

    var _inner: UInt32

    # ===--------------------------------------------------------------------===
    # Methods
    # ===--------------------------------------------------------------------===

    def __or__(self, other: Self) -> Self:
        return Self(self._inner & other._inner)

    def __and__(self, other: Self) -> Self:
        return Self(self._inner & other._inner)
