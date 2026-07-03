from professor.apple.cpu import Cpu

from .event import Event


@fieldwise_init
struct CpuEvent(
    Equatable, Event, ImplicitlyCopyable, RegisterPassable, Writable
):
    """A hardware event resolved for a specific `Cpu` generation.

    Type-level evidence that the event named `name()` exists on `cpu()`.
    Constructed by `AppleEventId.on()` and `PortableEventId.on()`.
    """

    var _cpu: Cpu
    var _name: StaticString

    # TODO: Reflection-synthesized `Equatable` currently miscompiles on
    # `StringSlice` fields (kgen.struct.gep error in reflect.mojo); remove
    # the manual implementations once fixed upstream.
    def __eq__(self, other: Self) -> Bool:
        return self._cpu == other._cpu and self._name == other._name

    def __ne__(self, other: Self) -> Bool:
        return not (self == other)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self._name, " on ", self._cpu)

    def name(self) -> StaticString:
        """The kpep event name, e.g. `"INST_ALL"`."""
        return self._name

    def cpu(self) -> Cpu:
        """The `Cpu` generation this event is resolved for."""
        return self._cpu
