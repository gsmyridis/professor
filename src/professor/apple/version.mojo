from .ffi.kperf import (
    KPC_PMU_ERROR,
    KPC_PMU_INTEL_V3,
    KPC_PMU_ARM_APPLE,
    KPC_PMU_INTEL_V2,
    KPC_PMU_ARM_V2,
    kpc_pmu_version,
)

@fieldwise_init
struct Version(
    RegisterPassable,
    Writable,
):
    """KPC PMU Version."""

    # ===------------------------------------------------------------------===#
    # Aliases
    # ===------------------------------------------------------------------===#

    comptime IntelV3 = Self(KPC_PMU_INTEL_V3)
    comptime ArmApple = Self(KPC_PMU_ARM_APPLE)
    comptime IntelV2 = Self(KPC_PMU_INTEL_V2)
    comptime ArmV2 = Self(KPC_PMU_ARM_V2)

    # ===------------------------------------------------------------------===#
    # Field
    # ===------------------------------------------------------------------===#

    var _value: UInt32

    # ===------------------------------------------------------------------===#
    # Lifetime methods
    # ===------------------------------------------------------------------===#

    def __init__(out self) raises:
        var version = kpc_pmu_version()
        if version == KPC_PMU_ERROR:
            raise Error("failed to get KPC PMU version")

        return Self(version)

    # ===------------------------------------------------------------------===#
    # Writable
    # ===------------------------------------------------------------------===#

    def write_to(self, mut writer: Some[Writer]):
        if self._value == KPC_PMU_ERROR:
            writer.write("Error")
        elif self._value == KPC_PMU_INTEL_V3:
            writer.write("Intel-V3")
        elif self._value == KPC_PMU_ARM_APPLE:
            writer.write("ARM-Apple")
        elif self._value == KPC_PMU_INTEL_V2:
            writer.write("Intel-V2")
        elif self._value == KPC_PMU_ARM_V2:
            writer.write("ARM-V2")
        else:
            self.write_repr_to(writer)
