from std.sys import CompilationTarget
from std.ffi import c_char, c_size_t

from .sys.kperf import kpc_cpu_string

# ===------------------------------------------------------------------------===
# CPU
# ===------------------------------------------------------------------------===


struct Cpu(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """Apple Silicon chip generation, as identified by `kpep_db.name`."""

    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    comptime M1 = Self(_mask=1 << 0)
    comptime M2 = Self(_mask=1 << 1)
    comptime M3 = Self(_mask=1 << 2)
    comptime M4 = Self(_mask=1 << 3)
    comptime M5 = Self(_mask=1 << 4)

    # ===--------------------------------------------------------------------===
    # Field
    # ===--------------------------------------------------------------------===

    var _mask: UInt8
    """One-hot generation bit used by Apple event availability masks."""

    # ===--------------------------------------------------------------------===
    # Lifetime methods
    # ===--------------------------------------------------------------------===

    @doc_hidden
    def __init__(out self, *, _mask: UInt8):
        self._mask = _mask

    @staticmethod
    def host() -> Self:
        """The Cpu generation this binary is compiled for.

        Resolved at compile time from the compilation target: by default
        the machine the binary is compiled on, not necessarily the one it
        runs on. Fails to compile for targets that are not a recognized
        Apple Silicon generation.
        """
        comptime if CompilationTarget.is_apple_m1():
            return Self.M1
        elif CompilationTarget.is_apple_m2():
            return Self.M2
        elif CompilationTarget.is_apple_m3():
            return Self.M3
        elif CompilationTarget.is_apple_m4():
            return Self.M4
        elif CompilationTarget.is_apple_m5():
            return Self.M5
        else:
            comptime assert False, (
                "compilation target is not recognized Apple Silicon. File an"
                " issue on GitHub."
            )

    def __init__(out self, *, database_name: StringSlice) raises:
        """Matches the name field from a Database to a known Cpu generation."""
        if database_name == "a14":
            return Self.M1
        elif database_name == "a15":
            return Self.M2
        elif (
            database_name == "a16"
            or database_name == "as1"
            or database_name == "as2"
            or database_name == "as3"
        ):
            return Self.M3
        elif (
            database_name == "as4"
            or database_name == "as4-1"
            or database_name == "as4-2"
        ):
            return Self.M4
        elif database_name == "as5" or database_name == "as5-2":
            return Self.M5

        raise Error(t"Unrecognised database name: {database_name}")

    # ===--------------------------------------------------------------------===
    # Writable methods
    # ===--------------------------------------------------------------------===

    def write_to(self, mut writer: Some[Writer]):
        if self == Self.M1:
            writer.write("M1")
        elif self == Self.M2:
            writer.write("M2")
        elif self == Self.M3:
            writer.write("M3")
        elif self == Self.M4:
            writer.write("M4")
        elif self == Self.M5:
            writer.write("M5")
        else:
            self.write_repr_to(writer)

    @always_inline
    def id(self) -> String:
        """Returns the current CPU identification string.

        This function does not require root privileges.

        Returns:
            The current CPU identification string.
        """
        # 64 bytes is assumed to be enough.
        # Array means string does not require allocation.
        var buf = Array[UInt8, 64](fill=0)
        var n = kpc_cpu_string(
            buf.unsafe_ptr().unsafe_bitcast[c_char](), c_size_t(len(buf))
        )
        if n < 0:
            return String()

        # SAFETY: It is assumed that the CPU identification
        # string is ASCII with length lower than 64 bytes.
        return String(unsafe_from_utf8_ptr=buf.unsafe_ptr())


# ===------------------------------------------------------------------------===
# Architecture
# ===------------------------------------------------------------------------===


struct Architecture(
    Equatable,
    ImplicitlyCopyable,
    RegisterPassable,
    Writable,
):
    # ===--------------------------------------------------------------------===
    # Aliases
    # ===--------------------------------------------------------------------===

    comptime I386 = Self(_value=0)
    comptime X86_64 = Self(_value=1)
    comptime Arm = Self(_value=2)
    comptime Arm64 = Self(_value=3)

    # ===--------------------------------------------------------------------===
    # Fields
    # ===--------------------------------------------------------------------===

    var _value: UInt32

    @doc_hidden
    def __init__(out self, *, _value: UInt32):
        self._value = _value

    # ===--------------------------------------------------------------------===
    # Writable methods
    # ===--------------------------------------------------------------------===

    def write_to(self, mut writer: Some[Writer]):
        if self._value == Self.I386._value:
            writer.write("i386")
        elif self._value == Self.X86_64._value:
            writer.write("x86_64")
        elif self._value == Self.Arm._value:
            writer.write("arm")
        elif self._value == Self.Arm64._value:
            writer.write("arm64")
        else:
            self.write_repr_to(writer)
