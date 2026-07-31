from std.sys import CompilationTarget, inlined_assembly

from .portable import read_cycle_counter


@always_inline
def cntfrq_el0() -> UInt64:
    """Reads the AArch64 system counter frequency register, `CNTFRQ_EL0`.

    Returns:
        The system counter frequency in hertz.
    """
    comptime assert (
        CompilationTarget.has_neon()
    ), "`cntfrq_el0()` requires an AArch64 compilation target"
    return inlined_assembly[
        "mrs $0, cntfrq_el0",
        UInt64,
        constraints="=r",
        has_side_effect=True,
    ]()


@always_inline
def cntvct_el0() -> UInt64:
    """Reads the AArch64 virtual system counter, `CNTVCT_EL0`.

    The counter advances at the frequency reported by `CNTFRQ_EL0`. It does not
    count CPU cycles and may include a hypervisor-provided offset from the
    physical system counter.

    Returns:
        The current virtual system-counter value.
    """
    comptime assert (
        CompilationTarget.has_neon()
    ), "`cntvct_el0()` requires an AArch64 compilation target"
    return read_cycle_counter()


@always_inline
def cntpct_el0() -> UInt64:
    """Reads the AArch64 physical system counter, `CNTPCT_EL0`.

    Access from EL0 depends on operating-system or hypervisor configuration and
    may trap when disabled.

    Returns:
        The current physical system-counter value.
    """
    comptime assert (
        CompilationTarget.has_neon()
    ), "`cntpct_el0()` requires an AArch64 compilation target"
    return inlined_assembly[
        "mrs $0, cntpct_el0",
        UInt64,
        constraints="=r",
        has_side_effect=True,
    ]()
