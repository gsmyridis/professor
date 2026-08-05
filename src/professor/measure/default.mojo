from std.time import perf_counter_ns
from std.sys import CompilationTarget
from std.os import abort

from .instrument import Instrument
from .quantity import Cycles, Nanos

from professor.arch import read_cycle_counter


struct WallClock(Defaultable, Instrument):
    """An `Instrument` that reads the monotonic wall clock."""

    comptime MetricType = Nanos

    def __init__(out self):
        pass

    def measure(mut self) -> Self.MetricType:
        return Self.MetricType(Int(perf_counter_ns()))


@fieldwise_init
struct InvariantTSC(Defaultable, Instrument):
    comptime MetricType = Cycles

    var value: UInt64

    def __init__(out self):
        return self.__init__(0)

    def measure(mut self) -> Self.MetricType:
        return Self.MetricType(Int(read_cycle_counter()))
