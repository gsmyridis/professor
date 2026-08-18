# Custom Instruments

An `Instrument` turns a cumulative measurement source into metrics Professor
can attribute to zones. Professor samples at each boundary and subtracts the
opening reading from the closing reading.

The built-in `WallClock` and `TimestampCounter` follow this model. A custom
instrument can expose an application counter, a device counter, or several
measurements collected together.

## The Instrument Contract

An instrument declares its metric type and implements a non-raising
`measure()` method:

```mojo
from professor import Count, Instrument


struct EventCounter(Instrument):
    comptime MetricType = Count["events"]

    var value: UInt64

    def __init__(out self):
        self.value = 0

    def measure(mut self) -> Self.MetricType:
        self.value += 10
        return Self.MetricType(self.value)
```

Readings must accumulate monotonically during a session. Professor computes
differences; a source that resets or decreases between boundaries produces a
wrapped, invalid result.

`Instrument` requires default construction so `GlobalProfiler` can initialize
its state lazily. A runtime `Profiler` may instead receive an explicitly
constructed instrument with runtime configuration.

## Supported Scalar Metrics

The metric type must be one of Professor's scalar quantity families or a flat
composite of them:

| Family | Common types | Use |
| --- | --- | --- |
| Time | `Nanos`, `Ticks`, `Time[unit]` | Elapsed time or architecture ticks. |
| Count | `Count["kind"]`, `Cycles` | Events such as cycles or cache misses. |
| Data size | `Bytes`, `DataSize[unit]` | Memory, I/O, or logical data volume. |

Units carry scale and meaning into reports. Prefer the most direct storage unit
provided by the source; report layout chooses a readable display unit later.

## Composite Metrics

A composite measures several scalar components at the same boundaries. Define
a `@fieldwise_init` struct that conforms to `Metric`:

```mojo
from professor import Count, Metric, Nanos


@fieldwise_init
struct CpuMetric(Metric):
    var elapsed: Nanos
    var cycles: Count["cycles"]
    var instructions: Count["instructions"]
    var cache_misses: Count["cache-misses"]
```

Professor derives zero construction, subtraction, addition, extrema, division,
and report decomposition through compile-time reflection. The struct only
declares its immediate fields.

Every field must be a supported scalar metric. Nested composites and unrelated
fields are rejected at compile time.

A report renders one table per field. Each table uses that component's program
total for percentages, so elapsed time and cache misses can identify different
bottlenecks.

## Returning a Composite Reading

The instrument returns all components in one reading:

```mojo
from professor import Count, Instrument, Nanos
from std.time import perf_counter_ns


struct CpuInstrument(Instrument):
    comptime MetricType = CpuMetric

    var events: EventSource

    def __init__(out self):
        self.events = EventSource()

    def measure(mut self) -> Self.MetricType:
        var now = UInt64(perf_counter_ns())
        var counters = self.events.read_or_abort()
        return Self.MetricType(
            Nanos(now),
            Count["cycles"](counters.cycles),
            Count["instructions"](counters.instructions),
            Count["cache-misses"](counters.cache_misses),
        )
```

`EventSource` is application-specific in this sketch. The important boundary
is that `measure()` returns one cumulative snapshot and does not raise.

## Errors on the Hot Path

Zone open and close are non-raising hot paths. An instrument that calls a
fallible OS or device API must handle the failure inside `measure()`, commonly
by aborting with useful context.

Do fallible setup before profiling where possible. A runtime `Profiler` can own
an instrument that was configured successfully before the first zone opens.

Do not silently replace a failed reading with zero. That preserves program
execution but corrupts deltas and can make a broken measurement look valid.

## Global and Runtime Construction

A default-constructible instrument works directly with a global profiler:

```mojo
from professor import GlobalProfiler

comptime Prof = GlobalProfiler[EventCounter, Tag="events"]
```

Use `Profiler` when configuration exists only at runtime:

```mojo
from professor import Profiler

var source = ConfiguredInstrument(config)
var prof = Profiler[ConfiguredInstrument](source^)
```

Each runtime profiler owns the transferred instrument. Separate profiler values
remain independent even when their types match.

## Cost and Boundary Size

Every zone performs two instrument reads. A wall-clock read is relatively
cheap; a syscall or multi-counter sample may cost enough to dominate a small
zone.

Measure instrument overhead with an empty or minimal zone, then choose regions
large enough that the source explains the workload rather than itself. Hardware
counters generally belong around coarser work.

Browse `examples/` for a complete counter-backed instrument that combines wall
time, cycles, instructions, and cache misses.

## Checklist

Before trusting a custom instrument, verify that:

- readings are cumulative and monotonically increasing;
- all fields refer to the same measurement interval;
- scalar types and units match the source;
- setup happens outside measured zones;
- failures cannot become plausible readings;
- read overhead is small relative to each zone;
- repeated runs produce an explainable distribution.
