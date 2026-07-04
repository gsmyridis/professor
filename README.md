# The Apple `kperf`/`kpc` FFI layer: a walkthrough

`kperf.framework` is a private macOS framework that gives near-zero-overhead
access to the CPU's hardware performance counters — cycles, instructions
retired, cache misses, branch mispredictions, and dozens of other
microarchitectural events. It's the same infrastructure that backs
Instruments and `xctrace`.

Two subsystems inside it matter here:

- **KPC** (Kernel Performance Counters) is the low-level API: which counter
  _classes_ are active, what each hardware register is programmed to count,
  and how to read the accumulated values back. `src/professor/apple/ffi/kperf.mojo`
  binds this directly.
- **kpep** is the layer on top of KPC that turns this from "poke raw
  registers" into "ask for an event by name." It ships a per-CPU plist
  database of named events (`FIXED_CYCLES`, `ARM_BR_MIS_PRED`, ...) and
  computes the raw KPC register values for whichever ones you pick.
  `src/professor/apple/ffi/kperf_data.mojo` binds this.

> **⚠️ Private & unstable.** `kperf.framework` and `kperfdata.framework` are
> private — their symbols aren't part of any public SDK, aren't documented
> by Apple, and carry no ABI stability guarantee. A macOS update can change
> struct layouts or remove a function outright; that's exactly why this FFI
> layer resolves every symbol at runtime (`dlopen`/`dlsym`) instead of
> linking against it. Treat everything in `apple/ffi/` as unstable.
>
> You'll also need **root** (`sudo`) to run any of this — acquiring and
> programming the hardware counters requires privileges a normal process
> doesn't have — and a **macOS / Apple Silicon** machine; the example output
> below is from an M4.

Everything below follows `examples/apple/ffi/measure.mojo` top to bottom —
open it alongside this doc. Run it yourself with:

```sh
sudo pixi run mojo -I src examples/apple/ffi/measure.mojo
```

## The kpep database

The starting point is a database of named events for the current CPU:

```mojo
var db = kperf_data.KPEPDb.MutPointerType.unsafe_dangling()
assert_success(kperf_data.kpep_db_create({}, UnsafePointer(to=db)))
```

Passing an empty name auto-detects the CPU via the `hw.cpufamily` sysctl and
loads the matching plist from `/usr/share/kpep` (or `/usr/local/share/kpep`).
The database is keyed by event name and alias; you look one up with
`kpep_db_event`:

```mojo
var event: OptionalUnsafePointer[kperf_data.KPEPEvent, MutUntrackedOrigin] = {}
assert_success(
    kperf_data.kpep_db_event(db, name_ptr, UnsafePointer(to=event))
)
```

Event names are CPU-specific — what exists on an M4 may not exist on an M1,
and there's no public list of them. If you're not sure of the exact
spelling, dump every event's name/alias/description first;
`examples/apple/ffi/kperf_data.mojo` does exactly that.

## Building a config

A config is a builder you add named events to:

```mojo
var cfg = kperf_data.KPEPConfig.MutPointerType.unsafe_dangling()
assert_success(kperf_data.kpep_config_create(db, UnsafePointer(to=cfg)))

assert_success(kperf_data.kpep_config_force_counters(cfg))

for name in event_names:
    var ev = find_event(db, name)
    assert_success(
        kperf_data.kpep_config_add_event(cfg, UnsafePointer(to=ev), 1, no_err)
    )
```

`kpep_config_force_counters` **must** be called before the first
`kpep_config_add_event` on Apple Silicon. The configurable PMC registers are
normally owned and driven by `powerd` for its own power/thermal management;
calling this flags the config so the register values it produces later
assume you're going to forcibly take those registers away from `powerd`
(next section). Skip it, and `kpep_config_add_event` fails with
`KPEP_CONFIG_ERROR_COUNTERS_NOT_FORCED` (error 13).

Each `kpep_config_add_event` call claims one hardware counter slot for that
event. The third argument (`flag`) is `0` to count in all CPU modes or `1`
for user-space only — more on why that matters in the appendix.

## Resolving classes and registers

Once your events are added, ask the config what it actually needs:

```mojo
var classes: UInt32 = 0
assert_success(kperf_data.kpep_config_kpc_classes(cfg, UnsafePointer(to=classes)))
```

`classes` is the union of every `KPC_CLASS_*_MASK` your chosen events pulled
in — fixed events (`FIXED_CYCLES`, `FIXED_INSTRUCTIONS`) pull in
`KPC_CLASS_FIXED_MASK`, general PMU events pull in
`KPC_CLASS_CONFIGURABLE_MASK`. You don't track this by hand; kpep built it up
as you called `kpep_config_add_event`.

Next, get the actual register contents kpep computed for you:

```mojo
var kpc_count: c_size_t = 0
assert_success(kperf_data.kpep_config_kpc_count(cfg, UnsafePointer(to=kpc_count)))

var kpc_config_buf = alloc(Layout[kperf.KPCConfig](count=Int(kpc_count))).unsafe_leak()
assert_success(
    kperf_data.kpep_config_kpc(cfg, kpc_config_buf, kpc_count * UInt(size_of[kperf.KPCConfig]()))
)
```

`KPCConfig` is just `UInt64` — one hardware config register's worth of
selector bits, in a bit layout Apple doesn't publish. `kpep_config_kpc_count`
is **not** the number of events you added; it's the total config-register
footprint of every _active class_. On an M4, `FIXED` needs zero config
registers (the fixed counters always measure the same thing — there's
nothing to select), while `CONFIGURABLE` reports its full slot count
regardless of how many you're actually using. With 2 fixed + 3 configurable
events added, `kpc_count` comes out as `8`: the first 3 configurable slots
hold real selector values, the remaining 5 are zeroed ("select nothing").

## Acquiring and programming the hardware

```mojo
assert_success(kperf.kpc_force_all_ctrs_set(1))
assert_success(kperf.kpc_set_config(classes, kpc_config_buf))
```

`kpc_force_all_ctrs_set(1)` is the other half of the `force_counters` call
from earlier — it actually takes the configurable counters away from
`powerd`. Without it, `kpc_set_config` fails.

`kpc_set_config(classes, kpc_config_buf)` takes both a mask and a buffer
because the mask tells the kernel how to slice the buffer: it holds
`kpc_get_config_count(FIXED)` entries followed by
`kpc_get_config_count(CONFIGURABLE)` entries, in that order. On this PMU,
`FIXED`'s region happens to have zero width, so passing `FIXED` in `classes`
here is actually a no-op for _this specific call_ — there's nothing for it
to claim in the buffer. It matters a lot in the next step, though.

## Starting counting: global vs. per-thread

KPC has two independent counting switches that both need to be set:

```mojo
assert_success(kperf.kpc_set_counting(classes))
assert_success(kperf.kpc_set_thread_counting(classes))
```

**Global counting** (`kpc_set_counting`) physically starts the hardware
registers for the given classes ticking, across all CPUs. This is where
`FIXED` actually matters — unlike `kpc_set_config`, this call doesn't care
about config-register width, it cares about which counter banks are running
at all. Leave `FIXED` out here and `FIXED_CYCLES`/`FIXED_INSTRUCTIONS` will
read back `0` forever, no matter what you passed to `kpc_set_config`.

**Per-thread counting** (`kpc_set_thread_counting`) controls which of those
_globally running_ classes the kernel shadows into per-thread storage — the
storage `kpc_get_thread_counters` reads. It's a filter on top of the global
state, not an independent switch: a class must be enabled in both for
per-thread reads to be meaningful. The effective set is the intersection:

```
effective = global_counting & thread_counting
```

For example, if global counting is `CONFIGURABLE` and thread counting is
`FIXED | CONFIGURABLE`, only `CONFIGURABLE` counters accumulate per-thread,
because the `FIXED` hardware was never started globally.

The kernel's counting state persists across process lifetimes until reset
(`kperf_reset`) or reboot — it isn't scoped to your process.

### Typical setup sequence

```
kpc_set_config(classes, config)      # program what each counter measures
kpc_force_all_ctrs_set(1)            # acquire the registers from powerd
kpc_set_counting(classes)            # start hardware counters globally
kpc_set_thread_counting(classes)     # enable per-thread accumulation
// ... workload ...
kpc_get_thread_counters(0, n, buf)   # read per-thread values
```

## Reading counters

`kpc_get_thread_counters` doesn't return one value per event — it returns
one `UInt64` per _absolute hardware slot_ (all `FIXED` slots, then all
`CONFIGURABLE` slots), regardless of which ones you actually populated. You
need the event-to-slot mapping to make sense of it:

```mojo
var slot_map = alloc(Layout[c_size_t](count=Int(events_count))).unsafe_leak()
assert_success(
    kperf_data.kpep_config_kpc_map(cfg, slot_map, events_count * UInt(size_of[c_size_t]()))
)

var counter_count = kperf.kpc_get_counter_count(classes)
var before = alloc(Layout[UInt64](count=Int(counter_count))).unsafe_leak()
var after = alloc(Layout[UInt64](count=Int(counter_count))).unsafe_leak()

assert_success(kperf.kpc_get_thread_counters(0, UInt32(counter_count), before))
var result = function_to_measure()
assert_success(kperf.kpc_get_thread_counters(0, UInt32(counter_count), after))
```

`slot_map[i]` gives the absolute slot that event `i` landed in, so
`after[slot_map[i]] - before[slot_map[i]]` is that event's delta over the
call to `function_to_measure`.

Keep the bracketed region to _only_ the code you actually want measured.
`function_to_measure` returns its result instead of printing it, and the
`print` happens after the `after` snapshot — deliberately. Anything you do
inside the window, including logging, gets counted as part of your
measurement. See the appendix for what that costs you in practice.

## Tearing down

```mojo
assert_success(kperf.kpc_set_thread_counting(0))
assert_success(kperf.kpc_set_counting(0))
assert_success(kperf.kpc_force_all_ctrs_set(0))
kperf_data.kpep_config_free(cfg)
kperf_data.kpep_db_free(db)
```

Stop per-thread accumulation, stop global counting, then release the forced
counters back to `powerd`. Leaving classes "on" keeps the PMCs running (and
withheld from `powerd`) for the rest of the process's life.

## Appendix: chasing down measurement noise

The first version of `function_to_measure` printed its result before
returning:

```mojo
def function_to_measure():
    var total: UInt64 = 0
    for i in range(1_000_000):
        total += UInt64(i)
    print("result:", total)
```

Since `print` ran _inside_ the `before`/`after` window, every run's
`FIXED_INSTRUCTIONS`/`FIXED_CYCLES` included whatever it cost to format that
string and `write(2)` it to the terminal — and that cost isn't fixed. Three
consecutive runs gave instruction counts of 23322, 23433, and 23490: a
~170-instruction spread from one run to the next, on code that should do the
exact same thing every time.

The first attempted fix was switching `kpep_config_add_event`'s `flag` from
`0` (count in all CPU modes) to `1` (user-space only). It didn't help. The
reason: `flag=1` only excludes _kernel-mode_ instructions — interrupts, page
faults, the kernel side of a syscall. It does nothing about the _user-mode_
work `print` still does before it ever traps into the kernel: formatting the
string, a heap allocation for it (which can take a faster or slower path
depending on allocator/heap state), and the libSystem syscall trampoline
itself. All of that stayed inside the window.

The actual fix was moving `print` out of the measured region entirely —
`function_to_measure` returns the value, and the caller prints it after the
`after` snapshot, as shown above. That dropped the counts from the
~23,000s/~24,000s down to ~12,000s/~4,800s — confirming that most of the
original variance, and a good chunk of the absolute count, was the
measurement harness's own overhead, not the loop being measured.

Even with `print` out of the way, expect a few percent of run-to-run jitter
to remain. `flag=1` filters _which instructions count_, not _whether your
thread can be interrupted_ — a scheduler tick or context switch landing
mid-loop can still perturb a region this short. If you need tighter numbers,
take several samples and use the minimum rather than the average: standard
microbenchmarking practice, since the minimum is the sample least disturbed
by other system activity.
