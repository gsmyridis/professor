# Professor

Professor is an instrumentation-based profiling library for Mojo.

It is meant to help answer two questions: where does your code spend most of
its time, and why is that time spent there?

Professor exposes performance measurements from the machine underneath your
program. Depending on the operating system and CPU ISA, those measurements may
come from hardware performance counters, kernel profiling APIs, architectural
registers, or timestamp counters.

Each tool has tradeoffs. Some counters are precise but privileged. Some timing
sources are cheap but explain less. Some APIs are powerful but platform
specific. Professor wraps those tools in safer Mojo APIs.

The library is also meant to make collection and reporting easy: run a small
measurement, collect the relevant metrics, and produce a report that points at
likely bottlenecks and explains the supporting evidence.

## Roadmap

- Apple Silicon/macOS: `kperf`, KPC, and KPEP access to hardware performance
  counters.
- Linux: `perf_event_open` and perf events. Not implemented.
- x86_64: `rdtsc`/`rdtscp` timing support. Not implemented.
- AArch64: user-readable `*_EL0` counter registers where the OS enables them.
  Not implemented.
- Reporting: measurement collection and bottleneck reports. Not implemented.
- Other operating-system and ISA-specific backends where they are useful.

## Apple kperf Backend

The current backend targets Apple Silicon on macOS. It provides a Mojo wrapper
around hardware performance counters, including events such as cycles, retired
instructions, cache misses, and branch behavior.

The Apple backend uses the same private `kperf`, KPC, and KPEP machinery that
powers Instruments and `xctrace`. Professor adds a safer Mojo layer on top:
owned handles, typed events, automatic event-to-counter mapping, and per-thread
sampling helpers.

> Important: this backend is macOS-only, Apple-Silicon-only, and requires
> `sudo`. Apple's `kperf.framework` and `kperfdata.framework` are private
> frameworks: Apple does not publish headers, documentation, or ABI guarantees
> for them. This project relies on reverse-engineered layouts and behavior. A
> macOS update can break the bindings or change counter semantics.

The private frameworks were reverse engineered by other researchers. Add their
names and links here before treating this document as complete.

## The kperf System

Apple's private kperf system provides access to performance counters and
profiling events on macOS. It is powerful, but experimental for this project
because Apple can change the private ABI or event semantics at any time.

Professor uses three related layers:

- KPC, or Kernel Performance Counters, is the low-level counter interface in
  `kperf.framework`. It discovers counter classes, programs KPC config
  registers, starts counting, and reads per-thread or per-CPU counter values.
- KPERF, or Kernel Performance, is the timer and action sampling subsystem in
  `kperf.framework`. It configures sampler sets, action filters, timer periods,
  and tick/nanosecond conversion helpers.
- KPEP is the event database and config-builder layer in
  `kperfdata.framework`. It loads the per-CPU event database, maps names such
  as `FIXED_CYCLES` to hardware selectors, and produces KPC config words.

The flow is: KPEP decides which KPC registers and counter slots an event needs;
KPC programs and reads the counters; Professor owns the handles and translates
raw hardware slots back into the event order requested by Mojo code.

## Quick Start

Run the safe sampler example:

```sh
sudo pixi run mojo -I src examples/apple/sampler.mojo
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
counting, reads raw KPC values, and returns values in the same order as the
events you requested.

## What The Framework Does

Each Apple Silicon CPU core has a performance monitoring unit, or PMU. The PMU
counts occurrences of hardware events related to performance: cycles,
instructions, cache misses, branches, stalls, and similar microarchitectural
activity.

The PMU exposes physical counter registers. Each counter register stores a
number: how many times its selected event has occurred.

Some counter registers are fixed. A fixed counter always counts one event. On
Apple Silicon, `FIXED_CYCLES` and `FIXED_INSTRUCTIONS` are fixed counters, so
there is no event selector to program for them.

Other counter registers are configurable. A configurable counter can count one
event chosen from the PMU's supported event list, such as `L1D_CACHE_MISS_LD`
or `CORE_ACTIVE_CYCLE`.

Because configurable counters need to know what to count, each configurable
counter has a corresponding configuration register. In KPC these are the
`KPCConfig` values. A config register encodes the event selector and count mode,
for example whether the event should count userspace only or all modes.

The important distinction is:

- Counter register: the value being counted.
- Config register: the program that tells a configurable counter what to count.

Apple exposes this through two private layers:

- KPC, the low-level API for counter classes, KPC config registers, global
  counting, per-thread counting, and raw counter reads.
- kpep, the event database layer that maps names such as `FIXED_CYCLES` to the
  raw KPC config words for the current CPU.

Professor uses kpep to build a configuration, then uses KPC to program and read
the counters.

## The Safe API

Most code should start with `professor.apple.Sampler`.

```mojo
var sampler = Sampler()
var thread = sampler.thread([PortableEvent.Cycles, PortableEvent.Instructions])
```

`Sampler` owns the kpep database and resolves `PortableEvent` values for the
current CPU.

It also force-acquires the configurable PMCs from `powerd`. Apple normally lets
`powerd` use those counters for power and thermal management, so measuring PMU
events requires taking temporary ownership.

Use `ThreadSampler` to measure the current thread:

```mojo
thread.start()
var before = thread.sample()
var value = work_to_measure()
var after = thread.sample()
thread.stop()
```

The returned lists are in event order, not raw hardware-slot order. If you ask
for `[Cycles, Instructions]`, index `0` is cycles and index `1` is
instructions.

Keep the measured window small. Printing, allocation, formatting, and logging
inside the window are part of the measurement.

## Choosing Events

Use `PortableEvent` when you want an event available across supported Apple
Silicon generations:

```mojo
PortableEvent.Cycles
PortableEvent.Instructions
PortableEvent.L1DCacheMissLd
PortableEvent.CoreActiveCycle
```

Portable events store the kpep event name and are resolved against the runtime
database.

CPU-specific event sets are also exposed through `AppleEvent`, `M1Event`,
`M2Event`, `M3Event`, `M4Event`, and `M5Event`.

If an event is not available for the current CPU, event lookup raises instead of
passing an unchecked string to the C API.

To inspect what the current machine exposes, use:

```sh
sudo pixi run mojo -I src examples/apple/ffi/kperf_data.mojo
```

## Lower-Level Safe Configuration

Use `Database` and `ConfigBuilder` when you need to inspect or build a
configuration yourself.

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
database lifetime because Apple's config object stores pointers into it.

`cfg.force_counters()` must run before the first `add_event()` on Apple
Silicon. Without it, kpep rejects configurable-counter events with a
counter-not-forced error.

`build()` copies the runtime data into an owned `Configuration`:

- `classes`: the KPC classes that must be enabled.
- `registers`: raw KPC config words produced by kpep.
- `counter_map`: event index to hardware counter slot.
- `event_names`: configured event names in request order.
- `hardware_counter_count`: raw values needed for each KPC read.

This is the data `ThreadSampler` uses internally.

## Count Modes

`ConfigBuilder.add_event()` defaults to userspace-only counting:

```mojo
cfg.add_event(db.get_event(PortableEvent.Instructions))
```

Pass `CountMode.AllModes` to include kernel and system execution attributed to
the thread:

```mojo
from professor.apple import CountMode

cfg.add_event(
    db.get_event(PortableEvent.Instructions),
    mode=CountMode.AllModes,
)
```

Userspace-only mode filters which instructions count. It does not prevent the
thread from being interrupted or scheduled away.

For short measurements, take several samples and use the minimum. That is often
the sample least disturbed by scheduler and system activity.

## Internals: KPC Classes

KPC groups physical PMU registers into classes. The important Apple Silicon
classes are:

- `Classes.Fixed`: fixed counters such as cycles and instructions.
- `Classes.Configurable`: PMU counters programmed for selected events.

kpep computes the required class mask for the events you add. You should not
track this by hand.

Fixed counters may need no KPC config-register entries, because their event is
already fixed. They still need their class enabled when counting starts. A fixed
counter can read as zero forever if the fixed class is not globally enabled.

Configurable counters do need KPC config-register entries. Those entries are not
the measurements; they are the hardware programming words that tell each
configurable counter which event and mode to count.

## Internals: Programming And Reading

The raw KPC sequence is:

```text
kpc_force_all_ctrs_set(1)
kpc_set_config(classes, registers)
kpc_set_counting(classes)
kpc_set_thread_counting(classes)
kpc_get_thread_counters(0, count, buffer)
```

`kpc_set_config` writes the KPC config registers for the selected classes.
Global counting then starts the hardware counters. Per-thread counting tells
the kernel which globally-running classes to shadow into per-thread storage.

The effective per-thread set is:

```text
effective = global_counting & thread_counting
```

`kpc_get_thread_counters` returns raw hardware slots, not event-order values.
Professor's `Configuration.counter_map` translates those slots back to the
event order you requested.

## Cleanup

For the high-level API:

```mojo
thread.stop()
sampler.release()
```

`ThreadSampler.stop()` disables per-thread counting for the current thread.

`Sampler.release()` restores the previous force-counter state. The destructor
also restores it if you forget, but explicit release is clearer in long-running
programs.

The safe API does not clear global counting in its destructor. Global counting
is shared kernel state, and clearing it could break another sampler or profiler.

## FFI Layer

The direct bindings live under `src/professor/apple/ffi/`:

- `kperf.mojo` binds KPC and kperf functions.
- `kperf_data.mojo` binds kpep database and configuration functions.

The FFI layer resolves private framework symbols at runtime with `dlopen` and
`dlsym` instead of linking against private SDK symbols. The bindings are based
on reverse-engineered private interfaces, so struct layouts and function
behavior must be treated as unstable.

Use the FFI examples only when debugging the wrapper or exploring Apple's raw
interfaces:

```sh
sudo pixi run mojo -I src examples/apple/ffi/measure.mojo
sudo pixi run mojo -I src examples/apple/ffi/kperf_data.mojo
```

For normal measurement code, prefer `Sampler` and `ThreadSampler`.

## Measurement Noise

Anything inside the before/after window gets counted. This includes string
formatting, printing, allocation, and syscall setup.

This version measures only the work:

```mojo
var before = thread.sample()
var value = work_to_measure()
var after = thread.sample()
print(value)
```

This version measures the print too:

```mojo
var before = thread.sample()
var value = work_to_measure()
print(value)
var after = thread.sample()
```

The difference can be large for short regions. Keep the window narrow, avoid
I/O inside it, and sample repeatedly.
