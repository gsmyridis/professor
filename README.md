# Professor

Professor is an instrumentation-based profiling library for Mojo.

It is meant to help answer two questions: where does your code spend most of
its time, and why is that time spent there?

You mark _profile zones_ in your code — as coarse or as granular as you want —
and `professor` collects performance metrics for each zone.

## Why Professor

Mojo programs usually target SOTA performance.
Coarse measurements, like timing the whole program, are useful final metrics,
but fail to help you identify performance bottlenecks, i.e. _where_ your program
spends most of its time.
To improve performance systematically you need granular measurements that show
which parts of your code are fast and which are slow.

There are two complementary ways to get them:

- **Sampling profilers** (Instruments on macOS, `perf` on Linux) periodically
  interrupt your program, record where it is, and sample selected metrics.
  They are excellent tools and every programmer should learn them.
- **Instrumentation profilers** make you explicitly mark the regions you care
  about and collect exact per-region statistics, with semantic labels that
  survive inlining and optimization.

`professor` takes the second approach.
In addition, it exposes the machinery underneath your program,
-- hardware performance counters, kernel profiling APIs, timestamp counters --
wrapped in safer Mojo APIs, so your zones can measure not just _time_ but _why_:
cache misses, branch behavior, retired instructions, and more.

## Quick Start

```mojo
from professor import Profiler, WallClock

comptime Prof = Profiler[WallClock]

def parse(input: String) -> Int:
    var zone = Prof.zone["parse"]()
    var result = 0
    for codepoint in input.codepoints():
        result += Int(codepoint.is_ascii_digit())
    zone^.close()
    return result


def main() raises:
    var zone = Prof.zone["total"]()
    var count = parse("professor v0.1")
    zone^.close()

    print("digits:", count)
    print(Prof.report())
```

Run it from a clone of this repository:

```sh
pixi run mojo run -I src my_program.mojo
```

A zone is opened with a semantic label and closed explicitly. The zone handle
is a _linear_ value: the compiler forces you to consume it with
`zone^.close()`, so a forgotten close is a compile error, not a silent
measurement bug.

`Prof.report()` prints per-zone statistics: hit count, inclusive metric (time
spent in the zone, children included) and exclusive metric (time spent in the
zone minus nested zones). Recursive zones are accounted for correctly.

For a complete worked example — a JSON parser computing haversine distances,
with zones around parsing, tokenization, and computation — see
[`examples/haversine`](examples/haversine):

```sh
pixi run -e examples haversine-generate
pixi run -e examples haversine-profile
```

## Profile Zones

### Creating profilers

`Profiler` is parameterized over a `Measurer` (the metric source), an optional
zone `Capacity` (default 1024 zone sites), and an optional `Tag` that names
its global state:

```mojo
from professor.profile import Profiler
from professor.measure.default import WallClock

comptime ParsingProfiler = Profiler[WallClock, Tag="parse"]
comptime ComputeProfiler = Profiler[WallClock, Tag="compute", Capacity=16]
```

Defining your own profiler aliases makes it straightforward to run several
independent profilers at once, targeting different parts of the program,
potentially with different metrics.
Profilers with the same `Tag` (and parameters) share state; the default tag is `"default"`.

Conventionally you declare your profilers once, in a `profile.mojo` file, and
import them wherever you instrument:

```mojo
# profile.mojo
from professor.profile import Profiler
from professor.measure.default import WallClock

comptime MyProfiler = Profiler[WallClock]
```

```mojo
# main.mojo
from profile import MyProfiler


def do_work() -> Int:
    var zone = MyProfiler.zone["do_work"]()
    var result = ...  # do the work
    zone^.close()
    return result
```

### Zones, nesting, and error paths

Zones can also be scoped with a `with` statement, which closes them
automatically when the block exits — including on the unwind path of a
raising body:

```mojo
def compute(pairs: Value) raises -> Float64:
    with MyProfiler.zone["compute"]():
        return _compute(pairs)
```

Zones nest, and must close in LIFO order — Professor aborts on a mismatched close.
When you hold the zone as a linear value instead, every control-flow path must
consume it; in raising code, close the zone before propagating the error:

```mojo
def compute(pairs: Value) raises -> Float64:
    var zone = MyProfiler.zone["compute"]()
    var result: Float64
    try:
        result = _compute(pairs)
    except error:
        zone^.close()
        raise error^
    zone^.close()
    return result
```

Prefer `with` unless you need to close the zone somewhere other than the end
of a scope.

Each `zone["label"]()` call site gets its own anchor, resolved at runtime from the label and call location.
For hot paths where even that lookup matters, you can pin the anchor at compile time:

```mojo
var zone = MyProfiler.zone["hot_loop", 3]()  # anchor index chosen by you
```

### Reading the report

`report()` returns a `Report` you can print or inspect. For each zone it
currently includes:

- `count`: how many times the zone closed.
- `inclusive`: metric accumulated while the zone was open, children included.
- `exclusive`: inclusive minus the metric attributed to nested zones.

`report()` raises if any zone is still open, because exclusive metrics are
transiently inconsistent while a zone is in flight. Min/max/mean/variance per
zone are on the roadmap.

### Custom metrics: `Measurer` and `Sample`

Wall-clock time is the default metric, but any monotonically accumulating
reading works. A metric source implements the `Measurer` trait, and its
readings implement `Sample`:

```mojo
from professor.measure import Measurer, Sample


struct MySample(Copyable, Defaultable, ImplicitlyDeletable, Sample):
    ...  # __sub__, __add__, __mul__, __truediv__, min, max, write_to


struct MyMeasurer(Measurer):
    comptime S = MySample

    def __init__(out self):
        ...

    def measure(mut self) -> Self.S:
        ...


comptime MyProfiler = Profiler[MyMeasurer, Tag="custom"]
```

Samples are subtracted to form deltas and added to aggregate them;
multiplication, division by a count, and `min`/`max` exist so the profiler can
maintain online statistics. Samples may be multi-valued — for example, a pair
of hardware counters — with all operations applied elementwise. The
`Defaultable` constructor must produce the zero reading.

One caveat: zone open and close are on the measurement's hot path and are
non-raising. A `Measurer` that can fail (for example, one that talks to the
OS) must handle or `abort` on errors inside `measure()` rather than raise.

## OS Performance Counters

Beyond timing, Professor gives you access to the operating system's
performance-counter machinery:

- **Apple Silicon / macOS**: the private `kperf` and `kperfdata` frameworks —
  implemented today, documented below.
- **Linux**: `perf_event_open` — planned.
- **Windows**: will follow when Mojo supports the platform.

Each tool has tradeoffs.
Some counters are precise but privileged.
Some timing sources are cheap but explain less.
Some APIs are powerful but platform specific.
Professor wraps them in safer Mojo APIs -- owned handles, typed events,
automatic event-to-counter mapping -- so you can use them directly or
plug them into profile zones as custom measurers.

## Apple kperf Backend

The current backend targets Apple Silicon on macOS. It wraps hardware
performance counters, including events such as cycles, retired instructions,
cache misses, and branch behavior — the same private `kperf`, KPC, and KPEP
machinery that powers Instruments and `xctrace`.

> **Important:** this backend is macOS-only, Apple-Silicon-only, and requires
> `sudo`. Apple's `kperf.framework` and `kperfdata.framework` are private:
> Apple publishes no headers, documentation, or ABI guarantees for them. This
> project relies on layouts and behavior reverse engineered by others (see
> [Acknowledgments](#acknowledgments)). A macOS update can break the bindings
> or change counter semantics.

### Quick start

Run the safe sampler example:

```sh
sudo pixi run mojo run -I src examples/apple/sampler.mojo
```

Minimal usage looks like this:

```mojo
from std.benchmark import black_box

from professor.apple import Sampler, PortableEvent


def main() raises:
    var sampler = Sampler()
    var thread = sampler.thread(
        [PortableEvent.Cycles, PortableEvent.Instructions]
    )

    thread.start()

    var before = thread.sample()

    var result = 0
    for i in range(100):
        result = black_box(result + i)

    var after = thread.sample()
    thread.stop()

    for i in range(thread.event_count()):
        print(thread.event_names()[i], after[i] - before[i])
```

`Sampler` opens the event database, acquires the counters from `powerd`, and
restores the previous force-counter state when released or destroyed.

`ThreadSampler` programs the selected counters, starts global and per-thread
counting, reads raw KPC values, and returns them **in the order you requested
the events** — if you ask for `[Cycles, Instructions]`, index `0` is cycles —
not in raw hardware-slot order.

### What the hardware provides

Each Apple Silicon CPU core has a performance monitoring unit (PMU) that
counts hardware events: cycles, instructions, cache misses, branches, stalls,
and similar microarchitectural activity.

The PMU exposes physical **counter registers**. Some are _fixed_ — they always
count one event (`FIXED_CYCLES`, `FIXED_INSTRUCTIONS`), so there is nothing to
program. Others are _configurable_ — each has a corresponding **config
register** that encodes which event to count and in which mode (userspace
only, or all modes).

The distinction to keep in mind:

- Counter register: the value being counted.
- Config register: the program that tells a configurable counter what to
  count.

### The kperf system

Apple exposes the PMU through three related private layers, and Professor uses
all three:

- **KPC** (Kernel Performance Counters), in `kperf.framework`, is the
  low-level counter interface: discover counter classes, program KPC config
  registers, start counting, read per-thread or per-CPU values.
- **KPERF**, also in `kperf.framework`, is the timer and action sampling
  subsystem: sampler sets, action filters, timer periods, tick conversions.
- **KPEP**, in `kperfdata.framework`, is the event database and config
  builder: it loads the per-CPU event database, maps names such as
  `FIXED_CYCLES` to hardware selectors, and produces KPC config words.

The flow is: KPEP decides which KPC registers and counter slots an event
needs; KPC programs and reads the counters; Professor owns the handles and
translates raw hardware slots back into the event order requested by Mojo
code.

### Choosing events

Use `PortableEvent` for events available across all supported Apple Silicon
generations:

```mojo
PortableEvent.Cycles
PortableEvent.Instructions
PortableEvent.L1DCacheMissLd
PortableEvent.CoreActiveCycle
```

Portable events store the kpep event name and are resolved against the runtime
database. CPU-specific event sets are also exposed as `AppleEvent` (every
event seen on any Apple Silicon) and `M1Event` through `M5Event` (events for a
specific generation).

If an event is not available for the current CPU, lookup raises instead of
passing an unchecked string to the C API. To inspect what the current machine
exposes:

```sh
sudo pixi run mojo run -I src examples/apple/ffi/kperf_data.mojo
```

### Count modes

`ConfigBuilder.add_event()` defaults to userspace-only counting. Pass
`CountMode.AllModes` to include kernel and system execution attributed to the
thread:

```mojo
from professor.apple import CountMode

cfg.add_event(
    db.get_event(PortableEvent.Instructions),
    mode=CountMode.AllModes,
)
```

Userspace-only mode filters which instructions count; it does not prevent the
thread from being interrupted or scheduled away. For short measurements, take
several samples and use the minimum — it is usually the sample least disturbed
by scheduler and system activity.

### Cleanup

```mojo
thread.stop()
sampler.release()
```

`ThreadSampler.stop()` disables per-thread counting for the current thread.
`Sampler.release()` restores the previous force-counter state; the destructor
also restores it if you forget, but explicit release is clearer in
long-running programs.

The safe API deliberately does not clear _global_ counting in its destructor:
global counting is shared kernel state, and clearing it could break another
sampler or profiler.

### Lower-level configuration

Use `Database` and `ConfigBuilder` when you need to inspect or build a
configuration yourself:

```mojo
from professor.apple import Database, ConfigBuilder, PortableEvent


var db = Database()
var cfg = ConfigBuilder(db)

cfg.force_counters()
cfg.add_event(db.get_event(PortableEvent.Cycles))
cfg.add_event(db.get_event(PortableEvent.Instructions))

var configuration = cfg.build()
```

`Database` owns the kpep database handle. `ConfigBuilder` is tied to that
database's lifetime because Apple's config object stores pointers into it.

`cfg.force_counters()` must run before the first `add_event()` on Apple
Silicon; without it, kpep rejects configurable-counter events with a
counter-not-forced error.

`build()` copies the runtime data into an owned `Configuration`:

- `classes`: the KPC classes that must be enabled.
- `registers`: raw KPC config words produced by kpep.
- `counter_map`: event index to hardware counter slot.
- `event_names`: configured event names in request order.
- `hardware_counter_count`: raw values needed per KPC read.

This is the data `ThreadSampler` uses internally.

### Internals: KPC classes, programming, and reading

KPC groups physical PMU registers into classes. The important Apple Silicon
ones are `Classes.Fixed` (fixed counters such as cycles and instructions) and
`Classes.Configurable` (PMU counters programmed for selected events). kpep
computes the required class mask for the events you add; you should not track
it by hand.

Fixed counters need no config-register entries — their event is already fixed
— but their class must still be enabled when counting starts; a fixed counter
reads as zero forever otherwise. Configurable counters do need config-register
entries: those are not measurements, they are the hardware programming words.

The raw KPC sequence is:

```text
kpc_force_all_ctrs_set(1)
kpc_set_config(classes, registers)
kpc_set_counting(classes)
kpc_set_thread_counting(classes)
kpc_get_thread_counters(0, count, buffer)
```

Global counting starts the hardware counters; per-thread counting tells the
kernel which globally-running classes to shadow into per-thread storage. The
effective per-thread set is `global_counting & thread_counting`.
`kpc_get_thread_counters` returns raw hardware slots;
`Configuration.counter_map` translates them back to the event order you
requested.

### FFI layer

The direct bindings live under [`src/professor/apple/ffi/`](src/professor/apple/ffi/):

- `kperf.mojo` binds KPC and kperf functions.
- `kperf_data.mojo` binds kpep database and configuration functions.

Private framework symbols are resolved at runtime with `dlopen`/`dlsym`
instead of linking against private SDK symbols. The bindings are based on
reverse-engineered interfaces, so struct layouts and function behavior must be
treated as unstable.

Use the FFI examples only when debugging the wrapper or exploring Apple's raw
interfaces:

```sh
sudo pixi run mojo run -I src examples/apple/ffi/measure.mojo
sudo pixi run mojo run -I src examples/apple/ffi/kperf_data.mojo
```

For normal measurement code, prefer `Sampler` and `ThreadSampler`.

### Measurement noise

Anything inside the before/after window gets counted — string formatting,
printing, allocation, syscall setup. This version measures only the work:

```mojo
var before = thread.sample()
var value = work_to_measure()
var after = thread.sample()
print(value)
```

Moving the `print` before the second `sample()` makes it part of the
measurement, and the difference can be large for short regions. Keep the
window narrow, avoid I/O inside it, and sample repeatedly.

### Counters inside profile zones

The sampler works for standalone coarse measurements, but you can also feed
counters into the instrumentation profiler by wrapping a `ThreadSampler` in a
custom `Measurer` whose `Sample` carries, say, cycles and instructions per
zone. The one constraint, as noted above, is that `measure()` is on the
profiler's non-raising hot path, so kperf errors must abort rather than raise.
A ready-made counter-backed measurer is on the roadmap.

## Roadmap

Instrumentation profiler:

- Richer reports: per-zone min/max/mean/variance, source locations, and
  bottleneck summaries.
- A `TimestampCounter` measurer (cheap invariant TSC timing) next to
  `WallClock`.
- A ready-made hardware-counter `Measurer` for the Apple backend.
- Eventually, decorator ergonomics as language support arrives:

  ```mojo
  @professor.measure("do_work")
  def do_work() -> Int: ...
  ```

Backends:

- Apple Silicon/macOS: `kperf`, KPC, and KPEP access to hardware performance
  counters. Implemented.
- Linux: `perf_event_open` and perf events. Not implemented.
- x86_64: `rdtsc`/`rdtscp` timing support. Not implemented.
- AArch64: user-readable `*_EL0` counter registers where the OS enables them.
  Not implemented.
- Windows: when Mojo supports the platform.
- Other operating-system and ISA-specific backends where they are useful.

## Acknowledgments

Apple's kperf machinery is private and undocumented; this project stands on
the reverse-engineering work of others, notably
[ibireme's `kpc_demo.c`](https://gist.github.com/ibireme/173517c208c7dc333ba962c1f0d67d12)
and [Dougall Johnson's Apple Silicon CPU research](https://github.com/dougallj/applecpu).
