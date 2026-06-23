"""Hardware performance counter event metadata for Apple Silicon.

Ported from the `darwin-kperf` crate (events/src/lib.rs (EventInfo trait)), which is
auto-generated from the PMC database plists in `/usr/share/kpep/`.
Dual-licensed MIT / Apache-2.0: https://github.com/hashintel/hash/tree/main/libs/darwin-kperf

Do not edit by hand; regenerate via `scripts/port_kperf_events.py`.
"""


trait EventInfo:
    """Metadata for a hardware performance counter event on a specific chip."""

    def name(self) -> StaticString:
        ...

    def description(self) -> StaticString:
        ...

    def counters_mask(self) -> Optional[UInt32]:
        ...

    def number(self) -> Optional[UInt16]:
        ...

    def fixed_counter(self) -> Optional[UInt8]:
        ...

    def fallback(self) -> Optional[StaticString]:
        ...

    def aliases(self) -> List[StaticString]:
        ...
