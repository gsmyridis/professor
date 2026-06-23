from std.ffi import c_char

# ===-----------------------------------------------------------------------===#
# Aliases
# ===-----------------------------------------------------------------------===#

comptime ConstCStringPointer = OptionalUnsafePointer[
    c_char, origin=ImmutAnyOrigin
]
"""C `const char*` type."""

comptime c_void = OptionalUnsafePointer[NoneType, MutUntrackedOrigin]
"""C `void*` type."""
