"""Hardware performance counter event metadata for Apple Silicon.

Ported from the `darwin-kperf` crate (events/src/lib.rs (AnyEvent)), which is
auto-generated from the PMC database plists in `/usr/share/kpep/`.
Dual-licensed MIT / Apache-2.0: https://github.com/hashintel/hash/tree/main/libs/darwin-kperf

Do not edit by hand; regenerate via `scripts/port_kperf_events.py`.
"""

from .m1 import M1Event
from .m2 import M2Event
from .m3 import M3Event
from .m4 import M4Event
from .m5 import M5Event


struct _AnyEvent(EventInfo, ImplicitlyCopyable, Movable):
    """Erases which chip an event belongs to; backs `ResolvedEvent`."""

    var _cpu_tag: UInt8
    var _m1: Optional[M1Event]
    var _m2: Optional[M2Event]
    var _m3: Optional[M3Event]
    var _m4: Optional[M4Event]
    var _m5: Optional[M5Event]

    def __init__(out self, var event: M1Event):
        self._cpu_tag = 0
        self._m1 = event
        self._m2 = None
        self._m3 = None
        self._m4 = None
        self._m5 = None

    def __init__(out self, var event: M2Event):
        self._cpu_tag = 1
        self._m1 = None
        self._m2 = event
        self._m3 = None
        self._m4 = None
        self._m5 = None

    def __init__(out self, var event: M3Event):
        self._cpu_tag = 2
        self._m1 = None
        self._m2 = None
        self._m3 = event
        self._m4 = None
        self._m5 = None

    def __init__(out self, var event: M4Event):
        self._cpu_tag = 3
        self._m1 = None
        self._m2 = None
        self._m3 = None
        self._m4 = event
        self._m5 = None

    def __init__(out self, var event: M5Event):
        self._cpu_tag = 4
        self._m1 = None
        self._m2 = None
        self._m3 = None
        self._m4 = None
        self._m5 = event

    def name(self) -> StaticString:
        if self._cpu_tag == 0:
            return self._m1.value().name()
        elif self._cpu_tag == 1:
            return self._m2.value().name()
        elif self._cpu_tag == 2:
            return self._m3.value().name()
        elif self._cpu_tag == 3:
            return self._m4.value().name()
        elif self._cpu_tag == 4:
            return self._m5.value().name()
        return ""

    def description(self) -> StaticString:
        if self._cpu_tag == 0:
            return self._m1.value().description()
        elif self._cpu_tag == 1:
            return self._m2.value().description()
        elif self._cpu_tag == 2:
            return self._m3.value().description()
        elif self._cpu_tag == 3:
            return self._m4.value().description()
        elif self._cpu_tag == 4:
            return self._m5.value().description()
        return ""

    def counters_mask(self) -> Optional[UInt32]:
        if self._cpu_tag == 0:
            return self._m1.value().counters_mask()
        elif self._cpu_tag == 1:
            return self._m2.value().counters_mask()
        elif self._cpu_tag == 2:
            return self._m3.value().counters_mask()
        elif self._cpu_tag == 3:
            return self._m4.value().counters_mask()
        elif self._cpu_tag == 4:
            return self._m5.value().counters_mask()
        return None

    def number(self) -> Optional[UInt16]:
        if self._cpu_tag == 0:
            return self._m1.value().number()
        elif self._cpu_tag == 1:
            return self._m2.value().number()
        elif self._cpu_tag == 2:
            return self._m3.value().number()
        elif self._cpu_tag == 3:
            return self._m4.value().number()
        elif self._cpu_tag == 4:
            return self._m5.value().number()
        return None

    def fixed_counter(self) -> Optional[UInt8]:
        if self._cpu_tag == 0:
            return self._m1.value().fixed_counter()
        elif self._cpu_tag == 1:
            return self._m2.value().fixed_counter()
        elif self._cpu_tag == 2:
            return self._m3.value().fixed_counter()
        elif self._cpu_tag == 3:
            return self._m4.value().fixed_counter()
        elif self._cpu_tag == 4:
            return self._m5.value().fixed_counter()
        return None

    def fallback(self) -> Optional[StaticString]:
        if self._cpu_tag == 0:
            return self._m1.value().fallback()
        elif self._cpu_tag == 1:
            return self._m2.value().fallback()
        elif self._cpu_tag == 2:
            return self._m3.value().fallback()
        elif self._cpu_tag == 3:
            return self._m4.value().fallback()
        elif self._cpu_tag == 4:
            return self._m5.value().fallback()
        return None

    def aliases(self) -> List[StaticString]:
        if self._cpu_tag == 0:
            return self._m1.value().aliases()
        elif self._cpu_tag == 1:
            return self._m2.value().aliases()
        elif self._cpu_tag == 2:
            return self._m3.value().aliases()
        elif self._cpu_tag == 3:
            return self._m4.value().aliases()
        elif self._cpu_tag == 4:
            return self._m5.value().aliases()
        return List[StaticString]()
