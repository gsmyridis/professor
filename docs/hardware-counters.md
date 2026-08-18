# Hardware Counters

Hardware performance counters record CPU events such as cycles, retired
instructions, cache misses, and branch misses. They help explain why two zones
with similar source code consume different resources.

Professor exposes public, owned wrappers for Linux `perf_event` and Apple
Silicon thread counters. These APIs are experimental and have different
permission, stability, and scheduling models.

This guide covers only the public wrappers. It does not document raw system
bindings, register programming, or private framework internals.

## When Counters Help

Start with wall-clock time. Add counters after a time profile identifies a
region whose behavior needs explanation.

Useful comparisons include:

- cycles versus wall time to separate CPU work from waiting;
- instructions versus cycles to reason about work per cycle;
- cache misses versus processed data to investigate locality;
- branch misses versus input shape to investigate unpredictable control flow.

A counter is evidence, not a diagnosis. Event semantics vary by processor, and
ratios are meaningful only when their numerator and denominator describe the
same work.

## Measurement Cost

Counter reads are not free. Keep setup, allocation, formatting, and printing
outside the before/after window, then repeat short measurements.

Use counter-backed Professor instruments for coarse zones. If a pair of reads
is comparable to the work inside a zone, the profile mostly measures the
instrument.

## Linux Groups

Linux groups control several events as one measurement and read them
atomically. A `GroupBuilder` owns counters until `build()` transfers them into a
`Group`.

```mojo
from professor.os.linux import (
    CounterConfig,
    CounterToken,
    GroupBuilder,
    PerfEvent,
)


def main() raises:
    var builder = GroupBuilder()
    var cycles: CounterToken
    var instructions: CounterToken
    try:
        cycles = builder.add(CounterConfig(PerfEvent.CpuCycles))
        instructions = builder.add(CounterConfig(PerfEvent.Instructions))
    except error:
        try:
            _ = builder^.build()
        except:
            pass
        raise error^
    var group = builder^.build()

    group.reset()
    group.enable()
    run_workload()
    group.disable()

    var counts = group.read()
    print("cycles:", counts.count(cycles).value)
    print("instructions:", counts.count(instructions).value)
```

The tokens returned by `add()` identify results without exposing owned file
descriptors. A token belongs to the builder and group that created it.

### Multiplexing

The kernel may time-share a group when it contains more events than the PMU can
schedule together. `Counts.time_enabled` and `Counts.time_running` expose that
scheduling loss.

`counts.count(token).scaled()` estimates a full-interval count using those
times. Scaling raises if the counter did not run at all.

Treat heavily multiplexed results cautiously. Fewer events per group usually
produce measurements that are easier to interpret.

### Permissions

`perf_event_open` access depends on user identity, kernel configuration,
container policy, and the host's perf security settings. Permission errors are
environmental until the same event can be opened outside Professor.

The public wrappers do not change system policy. Ask the host administrator for
the least privilege needed by the workload rather than weakening a shared
machine globally.

Browse `examples/` for a runnable Linux group measurement.

## Apple Silicon Sampler

`Sampler` acquires the Apple counter resources and creates a thread-local
`ThreadSampler`. Samples are returned in the same order as the requested typed
events.

```mojo
from professor.os.apple import PortableEvent, Sampler


def main() raises:
    var sampler = Sampler()
    var thread = sampler.thread(
        [PortableEvent.Cycles, PortableEvent.Instructions]
    )
    thread.start()

    var before = thread.sample()
    run_workload()
    var after = thread.sample()

    thread.stop()
    sampler.release()

    print("cycles:", after[0] - before[0])
    print("instructions:", after[1] - before[1])
```

Use `PortableEvent` when a measurement should work across supported Apple
Silicon generations. CPU-specific event sets are available, but an unavailable
event raises during configuration rather than becoming an unchecked string.

### Ownership and thread affinity

The sampler owns its counter lease. `release()` restores the previous force-
counter state; destruction also restores it, but explicit release makes the
lifetime visible in long-running programs.

A `ThreadSampler` must be started, sampled, and stopped on the thread that
created it. It can be reused across multiple start/stop cycles on that thread.

### Privileges and stability

The Apple backend uses private `kperf` and `kperfdata` frameworks. It requires
elevated privileges, targets Apple Silicon, and has no ABI guarantee across
macOS releases.

Run the safe example from a source checkout with:

```sh
sudo pixi run mojo run -I src examples/apple/sampler.mojo
```

Treat a macOS update as a relevant variable when a previously working sampler
fails. Include the OS build, CPU generation, and requested events in a bug
report.

## Counters in Profile Zones

To attribute counters to zones, wrap the Linux group or Apple sampler in a
custom `Instrument` and return a composite `Metric`.

The instrument owns the counter source for the profiler's lifetime. Its
`measure()` method returns one cumulative snapshot and must handle errors
without raising.

Professor then creates one table per metric component. Keep wall time in the
composite when you need to distinguish CPU consumption from elapsed latency.

Browse `examples/` for this pattern with wall time, cycles, instructions, and
L1 data-cache misses. [Custom Instruments](custom-instruments.md) explains the
required contract.

## Interpretation Checklist

Before drawing a conclusion from counters, check that:

- the event exists and means what you think on this CPU;
- all compared events cover the same thread and interval;
- setup and output are outside the measurement;
- the workload is representative and repeated;
- multiplexing is absent or small enough to justify scaling;
- the zone is much larger than the sampling overhead;
- ratios compare compatible units and scopes.
