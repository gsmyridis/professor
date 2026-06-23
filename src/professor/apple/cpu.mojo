"""Hardware performance counter event metadata for Apple Silicon.

Ported from the `darwin-kperf` crate (events/src/lib.rs (Cpu)), which is
auto-generated from the PMC database plists in `/usr/share/kpep/`.
Dual-licensed MIT / Apache-2.0: https://github.com/hashintel/hash/tree/main/libs/darwin-kperf

Do not edit by hand; regenerate via `scripts/port_kperf_events.py`.
"""


@fieldwise_init
struct Cpu(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """Apple Silicon chip generation, as identified by `kpep_db.name`."""

    var _tag: UInt8

    comptime M1 = Self(0)
    comptime M2 = Self(1)
    comptime M3 = Self(2)
    comptime M4 = Self(3)
    comptime M5 = Self(4)

    comptime _MARKETING_NAMES: InlineArray[StaticString, 5] = [
        "Apple A14/M1",
        "Apple A15",
        "Apple A16",
        "Apple silicon",
        "Apple silicon",
    ]

    comptime _FIXED_COUNTERS: InlineArray[UInt32, 5] = [
        UInt32(3),
        UInt32(3),
        UInt32(3),
        UInt32(3),
        UInt32(3),
    ]

    comptime _CONFIG_COUNTERS: InlineArray[UInt32, 5] = [
        UInt32(1020),
        UInt32(1020),
        UInt32(1020),
        UInt32(1020),
        UInt32(1020),
    ]

    comptime _POWER_COUNTERS: InlineArray[UInt32, 5] = [
        UInt32(224),
        UInt32(224),
        UInt32(224),
        UInt32(224),
        UInt32(224),
    ]

    def __eq__(self, other: Self) -> Bool:
        return self._tag == other._tag

    def __ne__(self, other: Self) -> Bool:
        return self._tag != other._tag

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.marketing_name())

    @staticmethod
    def from_db_name(name: StringSlice) -> Optional[Self]:
        """Matches the `name` field from a `kpep_db` to a known generation."""
        if name == "a14":
            return Self.M1
        if name == "a15":
            return Self.M2
        if name == "a16" or name == "as1" or name == "as2" or name == "as3":
            return Self.M3
        if name == "as4" or name == "as4-1" or name == "as4-2":
            return Self.M4
        if name == "as5" or name == "as5-2":
            return Self.M5
        return None

    def marketing_name(self) -> StaticString:
        return Self._MARKETING_NAMES[Int(self._tag)]

    def fixed_counters(self) -> UInt32:
        return Self._FIXED_COUNTERS[Int(self._tag)]

    def config_counters(self) -> UInt32:
        return Self._CONFIG_COUNTERS[Int(self._tag)]

    def power_counters(self) -> UInt32:
        return Self._POWER_COUNTERS[Int(self._tag)]
