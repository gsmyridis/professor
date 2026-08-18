# Profiling Zones

A profile zone gives a program region a stable name and a measured boundary.
Professor aggregates every completed invocation at the same site, so a report
describes both cost and frequency.

This guide assumes the library is installed and profiling is enabled with
`-D PROFESSOR_PROFILE`. Start with the [quick start](../README.md#quick-start)
if you have not produced a report yet.

## Choosing a Profiler

Every profiler is parameterized by an `Instrument`, which determines what a
zone measures. `WallClock` is the usual starting point because elapsed time is
portable and directly connected to user-visible latency.

### Global profiler

`GlobalProfiler` is a static facade over one lazily created profiler. It works
well when zones in different functions or modules should contribute to one
report.

Declare the alias once:

```mojo
# profile.mojo
from professor import GlobalProfiler, WallClock

comptime Prof = GlobalProfiler[WallClock, Tag="application"]
```

Import `Prof` wherever the application needs a zone. The `Tag` distinguishes
global profilers that otherwise use the same instrument and capacity.

```mojo
# parser.mojo
from profile import Prof


def parse(input: String):
    with Prof.zone["parse"]():
        parse_input(input)
```

### Runtime profiler

`Profiler` is an ordinary runtime value. Each instance owns an instrument, a
zone registry, and independent measurements.

```mojo
from professor import Profiler, WallClock

var parsing = Profiler[WallClock]()
var computation = Profiler[WallClock, Capacity=16]()
```

A runtime profiler can also own an instrument constructed from runtime
configuration:

```mojo
var profiler = Profiler[MyInstrument](MyInstrument(config))
```

Use this form when instrument configuration or session ownership belongs to a
runtime object. Prefer `GlobalProfiler` for application-wide source
instrumentation.

## Session Lifecycle

`start()` samples the instrument at the beginning of the program interval.
`end()` samples it again after all zones have closed. `report()` is valid only
after that complete lifecycle.

```mojo
Prof.start()

# Open and close any number of zones.

Prof.end()
var report = Prof.report()
```

Professor rejects lifecycle mistakes instead of rendering partial data. It
reports calls to `end()` before `start()`, repeated starts or ends, reports
before `end()`, and lifecycle operations while a zone remains open.

Call `reset()` after a completed session to clear measurements while preserving
the instrument and registered sites. A reset profiler can then start a fresh
session.

## Scoped Zones

A scoped zone follows a lexical region and closes through `__exit__`:

```mojo
with Prof.zone["parse"]():
    parse_input()
```

This is the safest and clearest form when the measured work already occupies a
scope. It closes during normal exit and error unwinding.

The zone label is a compile-time `StaticString`. Choose a domain name that will
remain meaningful after functions are renamed or inlined.

## Nested Zones

Zones can contain children:

```mojo
with Prof.zone["parse"]():
    with Prof.zone["tokenize"]():
        tokenize()
    build_value()
```

The parent records the complete inclusive measurement. Its exclusive value is
the inclusive value minus work attributed to children.

Nested zones must close in last-in, first-out order. A mismatched close aborts,
while `end()`, `reset()`, and `report()` reject any remaining open zones.

The same zone site may recurse. Professor aggregates recursive entries without
turning nested self-invocations into unrelated sites.

## Explicitly Closed Zones

Bind the handle when the measured region should end before its surrounding
scope:

```mojo
var zone = Prof.zone["parse"]()
var result = parse_input()
zone^.close()
consume(result^)
```

The handle is linear. `close()` consumes it, so every control-flow path must
close exactly once. A forgotten close becomes a compile error rather than an
incomplete runtime measurement.

For code that may raise, close before propagating the error:

```mojo
var zone = Prof.zone["parse"]()
var result: Value
try:
    result = parse_input()
except error:
    zone^.close()
    raise error^
zone^.close()
```

Prefer a scoped zone when it expresses the same boundary. The explicit form is
valuable when later work in the scope must remain outside the measurement.

## Site Identity

A name-only zone is identified by its label and source location. Repeated calls
through one call site aggregate into one row; the same label at two source
locations creates two rows.

This default preserves useful distinctions without requiring a registry in
application code. Reports include the source location so equal labels remain
traceable.

## Indexed Zones

An explicit compile-time index bypasses automatic site registration:

```mojo
with Prof.zone["hot_loop", 3]():
    run_hot_loop()
```

Valid indices range from `0` through `Capacity - 1`. Uses of one index must
agree on the label, and uses from different source locations aggregate into the
same row.

Indexed zones suit hot call sites where registration and source-based lookup
matter. Measure first; the automatic form is simpler and is appropriate for
most instrumentation.

## Processed Data

When the logical workload is known at zone creation, provide it with `bytes=`:

```mojo
with Prof.zone["parse"](bytes=UInt64(input.byte_length())):
    parse_input(input)
```

Professor sums bytes across invocations. Elapsed-time reports divide aggregate
bytes by aggregate inclusive time to derive throughput.

When the amount becomes known during the operation, start at zero and update
the invocation-local handle:

```mojo
with Prof.zone["read"](bytes=UInt64(0)) as workload:
    var count = read_some_data()
    workload.add_bytes(UInt64(count))
```

The report omits processed-data columns when no site records bytes. A site with
zero elapsed time reports throughput as `N/A` rather than dividing by zero.

## Disabled Builds

Professor checks the `PROFESSOR_PROFILE` compile-time define. Without it,
runtime profiler storage and zone handles are zero-sized, and lifecycle and
zone operations become no-ops.

```sh
# Collect a profile.
pixi run mojo run -D PROFESSOR_PROFILE program.mojo

# Compile profiling out.
pixi run mojo run program.mojo
```

`is_enabled()` exposes the build mode for code that should exist only when a
report contains measurements:

```mojo
comptime if Prof.is_enabled():
    print(Prof.report())
```

An unconditional disabled `report()` is also valid, but contains no totals,
statistics, or rendered tables.

## Next Steps

[Reports](reports.md) explains how these measurements become tables and
structured statistics.
