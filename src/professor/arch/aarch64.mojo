from std.sys import inlined_assembly


@always_inline
def cntfrq_el0() -> UInt64:
    """Reads the system counter frequency register."""
    return inlined_assembly[
        "mrs $0, cntfrq_el0",
        UInt64,
        constraints="=r",
        has_side_effect=True,
    ]()


@always_inline
def cntvct_el0() -> UInt64:
    """Reads the virtual count register."""
    return inlined_assembly[
        "mrs $0, cntvct_el0",
        UInt64,
        constraints="=r",
        has_side_effect=True,
    ]()


@always_inline
def cntpct_el0() -> UInt64:
    """Reads the physical count register."""
    return inlined_assembly[
        "mrs $0, cntpct_el0",
        UInt64,
        constraints="=r",
        has_side_effect=True,
    ]()
