from std.ffi import c_char
from std.ffi import CStringSlice, c_char

# ===------------------------------------------------------------------------===
# Type aliases
# ===------------------------------------------------------------------------===

comptime ConstCStringPointer = OptionalUnsafePointer[
    c_char, ImmutUntrackedOrigin
]
"""Nullable C `const char*` with externally managed lifetime."""

comptime c_void = Optional[OpaquePointer[MutUntrackedOrigin]]
"""Nullable C `void*` with externally managed lifetime."""

# ===------------------------------------------------------------------------===
# C string utilities
# ===------------------------------------------------------------------------===


def cstr_to_slice[
    cstr_origin: ImmutOrigin, //, origin: ImmutOrigin
](ptr: OptionalUnsafePointer[c_char, cstr_origin]) -> StringSlice[origin]:
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
    cstr_origin: ImmutOrigin, //, origin: ImmutOrigin
](ptr: OptionalUnsafePointer[c_char, cstr_origin]) -> Optional[
    StringSlice[origin]
]:
    if not ptr:
        return None
    return cstr_to_slice[origin](ptr)


def cstr_to_string[
    origin: Origin, //
](ptr: OptionalUnsafePointer[c_char, origin]) -> String:
    if not ptr:
        return String("<NULL>")
    try:
        return String(unsafe_from_utf8_ptr=ptr[].bitcast[UInt8]())
    except:
        return String("<NON-UTF8>")


# ===------------------------------------------------------------------------===
# Pointer utilities
# ===------------------------------------------------------------------------===


def cast_optional_mut_ptr[
    T: AnyType,
    from_origin: MutOrigin,
    //,
    to_origin: MutOrigin,
](ptr: OptionalUnsafePointer[T, from_origin]) -> OptionalUnsafePointer[
    T, to_origin
]:
    if ptr:
        return ptr.value().unsafe_origin_cast[to_origin]()

    return None
