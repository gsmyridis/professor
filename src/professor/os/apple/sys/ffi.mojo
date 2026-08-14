from std.ffi import CStringSlice, OwnedDLHandle, c_char


# ===------------------------------------------------------------------------===
# Type aliases
# ===------------------------------------------------------------------------===


comptime ConstCStringPointer = OptionalPointer[c_char, ImmUntrackedOrigin]
"""Nullable C `const char*` with externally managed lifetime."""

comptime c_void = Optional[OpaquePointer[MutUntrackedOrigin]]
"""Nullable C `void*` with externally managed lifetime."""


# ===------------------------------------------------------------------------===
# Dynamic symbol loading
# ===------------------------------------------------------------------------===


def load_symbol[
    F: TrivialRegisterPassable
](handle: OwnedDLHandle, name: StringSlice) raises -> F:
    """Resolves a C function pointer from an open dynamic library.

    `get_symbol` hands back a pointer *to* the symbol; for a function the
    symbol address is the code itself, so the address is reinterpreted as
    the function pointer rather than loaded from. This is the same dance
    `_DLHandle._get_function` performs, except a missing symbol raises
    instead of aborting the process.

    The returned pointer carries no origin, so it does not keep `handle`
    alive. The caller must ensure the library outlives every call through
    it (e.g. both live in the same process-lifetime `_Global`).

    Parameters:
        F: The C ABI function pointer type of the symbol.

    Args:
        handle: The open dynamic library to resolve the symbol in.
        name: The name of the symbol to resolve.

    Returns:
        The resolved function pointer.

    Raises:
        If the symbol is not present in the library.
    """
    var ptr = handle.get_symbol[NoneType](name)
    if not ptr:
        raise Error("missing symbol: ", name)
    return Pointer(to=ptr.value()).unsafe_bitcast[F]()[]


# ===------------------------------------------------------------------------===
# C string utilities
# ===------------------------------------------------------------------------===


def cstr_to_slice[
    cstr_origin: ImmOrigin, //, origin: ImmOrigin
](ptr: OptionalPointer[c_char, cstr_origin]) -> StringSlice[origin]:
    """Reclaims a tracked origin for a C string borrowed from the FFI layer.

    Safety:
        The caller must ensure the memory behind `ptr` stays valid for at
        least `origin` (e.g. it is owned by the `Database` that `origin`
        is tied to) and that it is null-terminated UTF-8.
    """
    var cstr = CStringSlice[origin](
        unsafe_from_ptr=ptr.value().unsafe_origin_cast[origin]()
    )
    return StringSlice[origin](unsafe_from_utf8=cstr)


def cstr_to_slice_opt[
    cstr_origin: ImmOrigin, //, origin: ImmOrigin
](ptr: OptionalPointer[c_char, cstr_origin]) -> Optional[StringSlice[origin]]:
    if not ptr:
        return None
    return cstr_to_slice[origin](ptr)


def cstr_to_string[
    origin: Origin, //
](ptr: OptionalPointer[c_char, origin]) -> String:
    if not ptr:
        return String("<NULL>")
    try:
        return String(unsafe_from_utf8_ptr=ptr[].unsafe_bitcast[UInt8]())
    except:
        return String("<NON-UTF8>")


def _cast_optional_mut_ptr[
    T: AnyType,
    from_origin: MutOrigin,
    //,
    to_origin: MutOrigin,
](ptr: OptionalPointer[T, from_origin]) -> OptionalPointer[T, to_origin]:
    if ptr:
        return ptr.value().unsafe_origin_cast[to_origin]()

    return None
