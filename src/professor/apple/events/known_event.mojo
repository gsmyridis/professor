"""Hardware performance counter event metadata for Apple Silicon.

Ported from the `darwin-kperf` crate (events/src/lib.rs (Event, AnyEvent, ResolvedEvent)), which is
auto-generated from the PMC database plists in `/usr/share/kpep/`.
Dual-licensed MIT / Apache-2.0: https://github.com/hashintel/hash/tree/main/libs/darwin-kperf

Do not edit by hand; regenerate via `scripts/port_kperf_events.py`.
"""

from professor.apple.cpu import Cpu
from .event_info import EventInfo
from ._any_event import _AnyEvent
from .m1 import M1Event
from .m2 import M2Event
from .m3 import M3Event
from .m4 import M4Event
from .m5 import M5Event


@fieldwise_init
struct KnownEvent(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """A hardware performance counter event from Apple's kpep database.

    Chip-agnostic identifier covering Apple Silicon generations M1 through
    M5. Use `on(cpu)` to resolve it for a specific `Cpu`."""

    var _tag: UInt16

    comptime ArmBrMisPred = Self(0)
    comptime ArmBrPred = Self(1)
    comptime ArmL1DCache = Self(2)
    comptime ArmL1DCacheLmissRd = Self(3)
    comptime ArmL1DCacheRd = Self(4)
    comptime ArmL1DCacheRefill = Self(5)
    comptime ArmStall = Self(6)
    comptime ArmStallBackend = Self(7)
    comptime ArmStallFrontend = Self(8)
    comptime ArmStallSlot = Self(9)
    comptime ArmStallSlotBackend = Self(10)
    comptime ArmStallSlotFrontend = Self(11)
    comptime AtomicOrExclusiveFail = Self(12)
    comptime AtomicOrExclusiveSucc = Self(13)
    comptime BranchCallIndirMispredNonspec = Self(14)
    comptime BranchCondMispredNonspec = Self(15)
    comptime BranchIndirMispredNonspec = Self(16)
    comptime BranchMispredNonspec = Self(17)
    comptime BranchRetIndirMispredNonspec = Self(18)
    comptime CoreActiveCycle = Self(19)
    comptime FetchRestart = Self(20)
    comptime FixedCycles = Self(21)
    comptime FixedInstructions = Self(22)
    comptime FlushRestartOtherNonspec = Self(23)
    comptime InstAll = Self(24)
    comptime InstBarrier = Self(25)
    comptime InstBranch = Self(26)
    comptime InstBranchCall = Self(27)
    comptime InstBranchCond = Self(28)
    comptime InstBranchIndir = Self(29)
    comptime InstBranchRet = Self(30)
    comptime InstBranchTaken = Self(31)
    comptime InstIntAlu = Self(32)
    comptime InstIntLd = Self(33)
    comptime InstIntSt = Self(34)
    comptime InstLdst = Self(35)
    comptime InstSimdAlu = Self(36)
    comptime InstSimdAluVec = Self(37)
    comptime InstSimdLd = Self(38)
    comptime InstSimdSt = Self(39)
    comptime InstSmeEngineAlu = Self(40)
    comptime InstSmeEngineLd = Self(41)
    comptime InstSmeEnginePackingFused = Self(42)
    comptime InstSmeEngineScalarfp = Self(43)
    comptime InstSmeEngineSt = Self(44)
    comptime InterruptPending = Self(45)
    comptime L1DCacheMissLd = Self(46)
    comptime L1DCacheMissLdNonspec = Self(47)
    comptime L1DCacheMissSt = Self(48)
    comptime L1DCacheMissStNonspec = Self(49)
    comptime L1DCacheWriteback = Self(50)
    comptime L1DTlbAccess = Self(51)
    comptime L1DTlbFill = Self(52)
    comptime L1DTlbMiss = Self(53)
    comptime L1DTlbMissNonspec = Self(54)
    comptime L1ICacheMissDemand = Self(55)
    comptime L1ITlbFill = Self(56)
    comptime L1ITlbMissDemand = Self(57)
    comptime L2TlbMissData = Self(58)
    comptime L2TlbMissInstruction = Self(59)
    comptime LdBlockedBySmeLdst = Self(60)
    comptime LdNtUop = Self(61)
    comptime LdSmeNormalUop = Self(62)
    comptime LdSmeNtUop = Self(63)
    comptime LdUnitUop = Self(64)
    comptime LdUnitWaitingYoungL1DCacheMiss = Self(65)
    comptime LdstSmePredInactive = Self(66)
    comptime LdstSmeXpgUop = Self(67)
    comptime LdstUnitOldL1DCacheMiss = Self(68)
    comptime LdstUnitWaitingOldL1DCacheMiss = Self(69)
    comptime LdstUnitWaitingSmeEngineInstQueueFull = Self(70)
    comptime LdstUnitWaitingSmeEngineMemData = Self(71)
    comptime LdstX64Uop = Self(72)
    comptime LdstXpgUop = Self(73)
    comptime MapDispatchBubble = Self(74)
    comptime MapDispatchBubbleIc = Self(75)
    comptime MapDispatchBubbleItlb = Self(76)
    comptime MapDispatchBubbleSlot = Self(77)
    comptime MapIntSmeUop = Self(78)
    comptime MapIntUop = Self(79)
    comptime MapLdstUop = Self(80)
    comptime MapRecovery = Self(81)
    comptime MapRewind = Self(82)
    comptime MapSimdUop = Self(83)
    comptime MapStall = Self(84)
    comptime MapStallDispatch = Self(85)
    comptime MapStallNonrecovery = Self(86)
    comptime MapUop = Self(87)
    comptime MmuTableWalkData = Self(88)
    comptime MmuTableWalkInstruction = Self(89)
    comptime RetireUop = Self(90)
    comptime ScheduleEmpty = Self(91)
    comptime ScheduleUop = Self(92)
    comptime ScheduleWaitingSmeEngineRegData = Self(93)
    comptime SmeEngineSmEnable = Self(94)
    comptime SmeEngineSmZaEnable = Self(95)
    comptime SmeEngineZaEnabledSmDisabled = Self(96)
    comptime StBarrierBlockedBySmeLdst = Self(97)
    comptime StMemOrderViolLdNonspec = Self(98)
    comptime StNtUop = Self(99)
    comptime StSmeNormalUop = Self(100)
    comptime StSmeNtUop = Self(101)
    comptime StUnitUop = Self(102)

    comptime _M1_MAP: InlineArray[Optional[UInt16], 103] = [
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        UInt16(0),
        UInt16(1),
        UInt16(2),
        UInt16(3),
        UInt16(4),
        UInt16(5),
        UInt16(6),
        UInt16(7),
        UInt16(8),
        UInt16(9),
        UInt16(10),
        UInt16(11),
        UInt16(12),
        UInt16(13),
        UInt16(14),
        UInt16(15),
        None,
        UInt16(16),
        UInt16(17),
        UInt16(18),
        UInt16(19),
        UInt16(20),
        UInt16(21),
        UInt16(22),
        UInt16(23),
        None,
        UInt16(24),
        UInt16(25),
        None,
        None,
        None,
        None,
        None,
        UInt16(26),
        UInt16(27),
        UInt16(28),
        UInt16(29),
        UInt16(30),
        UInt16(31),
        UInt16(32),
        UInt16(33),
        UInt16(34),
        UInt16(35),
        UInt16(36),
        UInt16(37),
        UInt16(38),
        UInt16(39),
        UInt16(40),
        None,
        UInt16(41),
        None,
        None,
        UInt16(42),
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        UInt16(43),
        UInt16(44),
        UInt16(45),
        None,
        None,
        None,
        None,
        UInt16(46),
        UInt16(47),
        None,
        UInt16(48),
        UInt16(49),
        UInt16(50),
        UInt16(51),
        None,
        None,
        UInt16(52),
        UInt16(53),
        UInt16(54),
        UInt16(55),
        UInt16(56),
        None,
        None,
        None,
        None,
        None,
        UInt16(57),
        UInt16(58),
        None,
        None,
        UInt16(59),
    ]

    comptime _M2_MAP: InlineArray[Optional[UInt16], 103] = [
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        UInt16(0),
        UInt16(1),
        UInt16(2),
        UInt16(3),
        UInt16(4),
        UInt16(5),
        UInt16(6),
        UInt16(7),
        UInt16(8),
        UInt16(9),
        UInt16(10),
        UInt16(11),
        UInt16(12),
        UInt16(13),
        UInt16(14),
        UInt16(15),
        None,
        UInt16(16),
        UInt16(17),
        UInt16(18),
        UInt16(19),
        UInt16(20),
        UInt16(21),
        UInt16(22),
        UInt16(23),
        UInt16(24),
        UInt16(25),
        UInt16(26),
        None,
        None,
        None,
        None,
        None,
        UInt16(27),
        UInt16(28),
        UInt16(29),
        UInt16(30),
        UInt16(31),
        UInt16(32),
        UInt16(33),
        UInt16(34),
        UInt16(35),
        UInt16(36),
        UInt16(37),
        UInt16(38),
        UInt16(39),
        UInt16(40),
        UInt16(41),
        None,
        UInt16(42),
        None,
        None,
        UInt16(43),
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        UInt16(44),
        UInt16(45),
        UInt16(46),
        None,
        None,
        None,
        None,
        UInt16(47),
        UInt16(48),
        None,
        UInt16(49),
        UInt16(50),
        UInt16(51),
        UInt16(52),
        None,
        None,
        UInt16(53),
        UInt16(54),
        UInt16(55),
        UInt16(56),
        None,
        None,
        None,
        None,
        None,
        None,
        UInt16(57),
        UInt16(58),
        None,
        None,
        UInt16(59),
    ]

    comptime _M3_MAP: InlineArray[Optional[UInt16], 103] = [
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        UInt16(0),
        UInt16(1),
        UInt16(2),
        UInt16(3),
        UInt16(4),
        UInt16(5),
        UInt16(6),
        UInt16(7),
        UInt16(8),
        UInt16(9),
        UInt16(10),
        UInt16(11),
        UInt16(12),
        UInt16(13),
        UInt16(14),
        UInt16(15),
        None,
        UInt16(16),
        UInt16(17),
        UInt16(18),
        UInt16(19),
        UInt16(20),
        UInt16(21),
        UInt16(22),
        UInt16(23),
        UInt16(24),
        UInt16(25),
        UInt16(26),
        None,
        None,
        None,
        None,
        None,
        UInt16(27),
        UInt16(28),
        UInt16(29),
        UInt16(30),
        UInt16(31),
        UInt16(32),
        UInt16(33),
        UInt16(34),
        UInt16(35),
        UInt16(36),
        UInt16(37),
        UInt16(38),
        UInt16(39),
        UInt16(40),
        UInt16(41),
        None,
        UInt16(42),
        None,
        None,
        UInt16(43),
        None,
        None,
        None,
        UInt16(44),
        UInt16(45),
        None,
        None,
        UInt16(46),
        UInt16(47),
        UInt16(48),
        UInt16(49),
        UInt16(50),
        None,
        None,
        UInt16(51),
        UInt16(52),
        None,
        UInt16(53),
        UInt16(54),
        UInt16(55),
        UInt16(56),
        None,
        UInt16(57),
        UInt16(58),
        UInt16(59),
        UInt16(60),
        UInt16(61),
        UInt16(62),
        None,
        None,
        None,
        None,
        None,
        UInt16(63),
        UInt16(64),
        None,
        None,
        UInt16(65),
    ]

    comptime _M4_MAP: InlineArray[Optional[UInt16], 103] = [
        UInt16(0),
        UInt16(1),
        UInt16(2),
        UInt16(3),
        UInt16(4),
        UInt16(5),
        UInt16(6),
        UInt16(7),
        UInt16(8),
        UInt16(9),
        UInt16(10),
        UInt16(11),
        UInt16(12),
        UInt16(13),
        UInt16(14),
        UInt16(15),
        UInt16(16),
        UInt16(17),
        UInt16(18),
        UInt16(19),
        UInt16(20),
        UInt16(21),
        UInt16(22),
        UInt16(23),
        UInt16(24),
        UInt16(25),
        UInt16(26),
        UInt16(27),
        UInt16(28),
        UInt16(29),
        UInt16(30),
        UInt16(31),
        UInt16(32),
        UInt16(33),
        UInt16(34),
        UInt16(35),
        UInt16(36),
        UInt16(37),
        UInt16(38),
        UInt16(39),
        UInt16(40),
        UInt16(41),
        UInt16(42),
        UInt16(43),
        UInt16(44),
        UInt16(45),
        UInt16(46),
        UInt16(47),
        UInt16(48),
        UInt16(49),
        UInt16(50),
        UInt16(51),
        UInt16(52),
        UInt16(53),
        UInt16(54),
        UInt16(55),
        UInt16(56),
        UInt16(57),
        UInt16(58),
        UInt16(59),
        UInt16(60),
        UInt16(61),
        UInt16(62),
        UInt16(63),
        UInt16(64),
        UInt16(65),
        UInt16(66),
        UInt16(67),
        UInt16(68),
        UInt16(69),
        None,
        UInt16(71),
        UInt16(72),
        UInt16(73),
        UInt16(74),
        UInt16(75),
        UInt16(76),
        UInt16(77),
        UInt16(78),
        UInt16(79),
        UInt16(80),
        UInt16(81),
        UInt16(82),
        UInt16(83),
        UInt16(84),
        UInt16(85),
        UInt16(86),
        UInt16(87),
        UInt16(88),
        UInt16(89),
        UInt16(90),
        UInt16(91),
        UInt16(92),
        UInt16(93),
        UInt16(94),
        UInt16(95),
        UInt16(96),
        UInt16(97),
        UInt16(98),
        UInt16(99),
        UInt16(100),
        UInt16(101),
        UInt16(102),
    ]

    comptime _M5_MAP: InlineArray[Optional[UInt16], 103] = [
        UInt16(0),
        UInt16(1),
        UInt16(2),
        UInt16(3),
        UInt16(4),
        UInt16(5),
        UInt16(6),
        UInt16(7),
        UInt16(8),
        UInt16(9),
        UInt16(10),
        UInt16(11),
        UInt16(12),
        UInt16(13),
        UInt16(14),
        UInt16(15),
        UInt16(16),
        UInt16(17),
        UInt16(18),
        UInt16(19),
        UInt16(20),
        UInt16(21),
        UInt16(22),
        UInt16(23),
        UInt16(24),
        UInt16(25),
        UInt16(26),
        UInt16(27),
        UInt16(28),
        UInt16(29),
        UInt16(30),
        UInt16(31),
        UInt16(32),
        UInt16(33),
        UInt16(34),
        UInt16(35),
        UInt16(36),
        UInt16(37),
        UInt16(38),
        UInt16(39),
        UInt16(40),
        UInt16(41),
        UInt16(42),
        UInt16(43),
        UInt16(44),
        UInt16(45),
        UInt16(46),
        UInt16(47),
        UInt16(48),
        UInt16(49),
        UInt16(50),
        UInt16(51),
        UInt16(52),
        UInt16(53),
        UInt16(54),
        UInt16(55),
        UInt16(56),
        UInt16(57),
        UInt16(58),
        UInt16(59),
        UInt16(60),
        UInt16(61),
        UInt16(62),
        UInt16(63),
        UInt16(64),
        UInt16(65),
        UInt16(66),
        UInt16(67),
        UInt16(68),
        UInt16(69),
        None,
        UInt16(71),
        UInt16(72),
        UInt16(73),
        UInt16(74),
        UInt16(75),
        UInt16(76),
        UInt16(77),
        UInt16(78),
        UInt16(79),
        UInt16(80),
        UInt16(81),
        UInt16(82),
        UInt16(83),
        UInt16(84),
        UInt16(85),
        UInt16(86),
        UInt16(87),
        UInt16(88),
        UInt16(89),
        UInt16(90),
        UInt16(91),
        UInt16(92),
        UInt16(93),
        UInt16(94),
        UInt16(95),
        UInt16(96),
        UInt16(97),
        UInt16(98),
        UInt16(99),
        UInt16(100),
        UInt16(101),
        UInt16(102),
    ]

    def __eq__(self, other: Self) -> Bool:
        return self._tag == other._tag

    def __ne__(self, other: Self) -> Bool:
        return self._tag != other._tag

    def write_to(self, mut writer: Some[Writer]):
        writer.write("KnownEvent(", Int(self._tag), ")")

    def on(self, cpu: Cpu) -> Optional[ResolvedEvent]:
        """Resolves this event for `cpu`, or `None` if unavailable there."""
        if cpu == Cpu.M1:
            var t = Self._M1_MAP[Int(self._tag)]
            if t:
                return ResolvedEvent(M1Event(t.value()))
            return None
        elif cpu == Cpu.M2:
            var t = Self._M2_MAP[Int(self._tag)]
            if t:
                return ResolvedEvent(M2Event(t.value()))
            return None
        elif cpu == Cpu.M3:
            var t = Self._M3_MAP[Int(self._tag)]
            if t:
                return ResolvedEvent(M3Event(t.value()))
            return None
        elif cpu == Cpu.M4:
            var t = Self._M4_MAP[Int(self._tag)]
            if t:
                return ResolvedEvent(M4Event(t.value()))
            return None
        elif cpu == Cpu.M5:
            var t = Self._M5_MAP[Int(self._tag)]
            if t:
                return ResolvedEvent(M5Event(t.value()))
            return None
        return None


@fieldwise_init
struct ResolvedEvent(EventInfo, ImplicitlyCopyable, Movable):
    """A `KnownEvent` resolved for a specific `Cpu`.

    Wraps a chip-specific event and forwards `EventInfo` to its
    chip-specific implementation."""

    var _inner: _AnyEvent

    def __init__(out self, var event: M1Event):
        self._inner = _AnyEvent(event)

    def __init__(out self, var event: M2Event):
        self._inner = _AnyEvent(event)

    def __init__(out self, var event: M3Event):
        self._inner = _AnyEvent(event)

    def __init__(out self, var event: M4Event):
        self._inner = _AnyEvent(event)

    def __init__(out self, var event: M5Event):
        self._inner = _AnyEvent(event)

    def name(self) -> StaticString:
        return self._inner.name()

    def description(self) -> StaticString:
        return self._inner.description()

    def counters_mask(self) -> Optional[UInt32]:
        return self._inner.counters_mask()

    def number(self) -> Optional[UInt16]:
        return self._inner.number()

    def fixed_counter(self) -> Optional[UInt8]:
        return self._inner.fixed_counter()

    def fallback(self) -> Optional[StaticString]:
        return self._inner.fallback()

    def aliases(self) -> List[StaticString]:
        return self._inner.aliases()
