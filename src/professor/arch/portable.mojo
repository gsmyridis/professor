from std.sys import llvm_intrinsic


@always_inline
def read_cycle_counter() -> UInt64:
    """Reads the target's low-latency hardware counter.

    On x86, this reads the timestamp counter (TSC). On AArch64, it reads
    `CNTVCT_EL0`, the Arm Generic Timer virtual count register. The returned
    value is target-dependent and does not necessarily represent CPU cycles.

    On unsupported targets, LLVM may return zero. Counter availability may
    also depend on operating-system and privilege-level configuration.

    Returns:
        The current target-specific counter value.
    """
    return llvm_intrinsic["llvm.readcyclecounter", UInt64]()
