from std.sys.info import CompilationTarget


def is_aarch64() -> Bool:
    """Checks if the target is an aarch64 architecture.

    Returns:
        True if the target is aarch64, False otherwise.
    """
    return CompilationTarget.has_neon()


def architecture_map[
    T: Copyable,
    //,
    operation: Optional[String] = None,
    *,
    aarch64: Optional[T] = None,
    x86: Optional[T] = None,
]() -> T:
    """Helper for defining a compile time value depending
    on the current compilation target, raising a compilation
    error if trying to access the value on an unsupported target.

    Parameters:
        T: The type of the platform-specific value.
        operation: Optional operation name for error messages.
        aarch64: The value to use on Aarch64 architectures.
        x86: The value to use on x86 architectures.

    Returns:
        The platform-specific value for the current target.
    """

    comptime if CompilationTarget.is_x86() and x86:
        return materialize[x86.value()]()
    elif is_aarch64() and aarch64:
        return materialize[aarch64.value()]()
    else:
        CompilationTarget.unsupported_target_error[operation=operation]()
