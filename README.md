# TODO:

- Check the `sysctl` thing and when it requires root.
- Replace comptime c_void with OpaquePointer.
-

The reason I use the \_Symbols

## KPC counting: global vs per-thread

KPC has two independent counting switches that both need to be set.

**Global counting** (`kpc_set_counting` / `kpc_get_counting`) controls the
hardware PMC registers. It determines which counter classes (`KPC_CLASS_*_MASK`)
are physically active across all CPUs. Setting this is what starts the hardware
ticking. Without it, no counters increment at all.

**Per-thread counting** (`kpc_set_thread_counting` / `kpc_get_thread_counting`)
controls which of those globally-running counter classes the kernel shadows into
per-thread storage. This per-thread storage is what `kpc_get_thread_counters`
reads back. It is a filter on top of the global state — a class must be enabled
in both for per-thread reads to contain meaningful values.

The effective set of classes accumulated per-thread is the intersection of the
two masks:

```
effective = global_counting & thread_counting
```

For example, if global counting is `CONFIGURABLE` and thread counting is
`FIXED | CONFIGURABLE`, only `CONFIGURABLE` counters are accumulated per-thread
because the FIXED hardware counters were never started globally.

The kernel counting state persists across process lifetimes until explicitly
reset or the system reboots. Call `kperf_reset` to restore a clean slate.

### Typical setup sequence

```
kpc_set_config(classes, config)      # program what each counter measures
kpc_set_counting(classes)            # start hardware counters globally
kpc_set_thread_counting(classes)     # enable per-thread accumulation
// ... workload ...
kpc_get_thread_counters(0, n, buf)   # read per-thread values
```

Database gives access to events.
Events basically give you descriptions of counters.

Witht the help of the database you create a config.
The config is used to setup the counters / sampler.
You read back with config.
