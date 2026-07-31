from std.sys import CompilationTarget, _RegisterPackType, llvm_intrinsic


@always_inline
def rdtsc() -> UInt64:
    """Reads the x86 timestamp counter using `RDTSC`.

    `RDTSC` is not serializing. The counter's rate and invariance depend on the
    target processor.

    Returns:
        The current timestamp-counter value.
    """
    comptime assert (
        CompilationTarget.is_x86()
    ), "`rdtsc()` requires an x86 compilation target"
    return llvm_intrinsic["llvm.readcyclecounter", UInt64]()


@always_inline
def rdtscp() -> UInt64:
    """Reads the x86 timestamp counter using `RDTSCP`.

    `RDTSCP` waits until prior instructions have executed and prior loads are
    globally visible. It does not wait for prior stores to become globally
    visible or prevent subsequent instructions from starting. The instruction
    also reads `IA32_TSC_AUX`; this function discards that value. The counter's
    rate and invariance depend on the target processor, which must support the
    `RDTSCP` instruction.

    Returns:
        The current timestamp-counter value.
    """
    comptime assert (
        CompilationTarget.is_x86()
    ), "`rdtscp()` requires an x86 compilation target"
    var result = llvm_intrinsic[
        "llvm.x86.rdtscp", _RegisterPackType[UInt64, UInt32]
    ]()
    return result[0]
