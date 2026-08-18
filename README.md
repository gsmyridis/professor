# Professor

Professor is an instrumentation-based profiling library for Mojo.

It helps answer two questions: where does your code spend most of its time, and
why is that time spent there?

You mark profile zones in your code, as coarse or as granular as you need, and
Professor collects performance metrics for each zone.

## How Professor Works

Professor measures *zones*: named regions that carry meaning in your program,
such as `parse`, `tokenize`, or `solve`. It records how often each zone runs and
how much of the selected metric it consumes.

Zones may nest. Inclusive time covers the complete zone, including its
children. Exclusive time removes child work, which separates orchestration
from the work delegated to nested zones.

This complements sampling profilers such as Instruments and `perf`. Sampling
discovers hot instructions without changing the program; instrumentation gives
exact boundaries and semantic labels that remain useful after inlining.

Use both when the question calls for both. Sampling finds unexpected hot code;
Professor compares regions you care about and can attach metrics that explain
why their costs differ.

## Installation

`professor` is available in the
[`modular-community`](https://prefix.dev/channels/modular-community) package
repository. Include the channel in your `pixi.toml`:

```toml
[workspace]
channels = [
  "https://conda.modular.com/max-nightly",
  "https://repo.prefix.dev/modular-community",
  "conda-forge",
]
```

Then install the package with `pixi add professor`, or specify the desired
version range in `pixi.toml`.

## Quick Start

The following program profiles a small two-stage pipeline. The outer zone
measures the complete operation; its children show where that time goes.

```mojo
from professor import GlobalProfiler, WallClock


comptime Prof = GlobalProfiler[WallClock, Tag="quickstart"]


def main() raises:
    Prof.start()

    var checksum = 0
    for batch in range(20):
        with Prof.zone["pipeline"]():
            var values = List[Int]()

            with Prof.zone["prepare"]():
                for i in range(50_000):
                    values.append((i * 17 + batch) % 997)

            with Prof.zone["aggregate"]():
                for value in values:
                    checksum += value

    Prof.end()

    print("checksum:", checksum)
    print(Prof.report())
```

Save it as `quickstart.mojo` and run it with profiling enabled:

```sh
pixi run mojo run -D PROFESSOR_PROFILE quickstart.mojo
```

The timings vary by machine, but the rendered report has this form:

```text
checksum: 497857452
Program total: 1.89 ms

Zone       Site                            Count  Inclusive (ms)  Exclusive (ms)  Inclusive Min. (us)  Inclusive / Iter. (us)  Inclusive (%)  Exclusive (%)
---------  ------------------------------  -----  --------------  --------------  -------------------  ----------------------  -------------  -------------
pipeline   examples/quickstart.mojo:12:35     20            1.88               0                   86                   94.15          99.8%           0.2%
prepare    examples/quickstart.mojo:15:38     20            1.49            1.49                   67                   74.45          78.9%          78.9%
aggregate  examples/quickstart.mojo:19:40     20            0.39            0.39                   19                   19.55          20.7%          20.7%
```

The `-D PROFESSOR_PROFILE` define must appear before the source path. Arguments
after the path belong to the program rather than the compiler.

`start()` and `end()` delimit the program-wide measurement interval. Zones
inside that interval sample `WallClock` when they open and close, then
`report()` aggregates all invocations at each call site.

The repository keeps this program in `examples/quickstart.mojo` and tests it
with profiling both enabled and disabled.

## Reading the Report

Each row identifies a zone and its source location, then reports how often that
site ran. Inclusive values contain nested work; exclusive values subtract it.
The report also shows the minimum and average inclusive value per invocation.

The parent `pipeline` is almost the full program interval, but has little
exclusive time. Its children explain the cost. Since `prepare` takes roughly
four times as long as `aggregate`, optimization should begin there.

Percentages can overlap when zones nest, so they are not expected to sum to
100%. Read parent and child rows as a hierarchy of attribution, not as unrelated
slices of a pie chart.

Processed-data and throughput columns appear when zones include workload sizes.
See [Reports](docs/reports.md) for every column, format selection, composite
metrics, and CSV export.

## Profiling Zones

A profile zone marks a meaningful region of the program. Professor aggregates
every invocation of that zone, recording both how often it runs and how much of
the selected metric it consumes.

Use a scoped zone when the measurement follows a lexical block:

```mojo
with Prof.zone["parse"]():
    parse_input()
```

Zones can nest, allowing a report to distinguish the total cost of an operation
from the work performed by its children:

```mojo
with Prof.zone["parse"]():
    with Prof.zone["tokenize"]():
        tokenize(input)
    build_value()
```

`start()` and `end()` define the complete profiling interval. All zones must
close before the session ends and before a report is produced.

Profiling is enabled with `-D PROFESSOR_PROFILE`. Without the define, profiler
storage and zone handles are zero-sized, and profiling operations become
no-ops.

See [Profiling Zones](docs/profiling-zones.md) for profiler ownership,
explicitly closed zones, indexed sites, processed data, and lifecycle rules.

## Going Deeper

Professor is parameterized by an `Instrument`. `WallClock` measures elapsed
nanoseconds, while `TimestampCounter` reads an invariant architecture counter.
Custom instruments can return time, counts, data sizes, or a flat composite.

Composite metrics produce one report table per component. This lets the same
zones tell different stories: a waiting zone may dominate wall time while a
compute-heavy zone dominates cycles.

See [Custom Instruments](docs/custom-instruments.md) for the measurement
contract and supported metric shapes.

Professor also provides typed, owned wrappers around Linux `perf_event` groups
and Apple Silicon counters. Their permissions, overhead, and stability differ;
read [Hardware Counters](docs/hardware-counters.md) before using them.

For microbenchmarks, `RepetitionTester` repeats a workload until its measured
components stop finding better minima. It shares the instrument model but
answers a different question from zone profiling.

See [Repetition Testing](docs/repetition-testing.md) for stopping rules,
batching, and result interpretation.

## Documentation

- [Documentation index](docs/README.md)
- [Profiling zones](docs/profiling-zones.md)
- [Reports](docs/reports.md)
- [Custom instruments](docs/custom-instruments.md)
- [Hardware counters](docs/hardware-counters.md)
- [Repetition testing](docs/repetition-testing.md)

Browse `examples/` for complete programs that exercise the library.

## Compatibility

Professor's package and test environments currently target these platforms:

| Capability | Platforms | Notes |
| --- | --- | --- |
| Zone profiling and reports | macOS ARM64, Linux x86-64, Linux ARM64 | Uses portable wall-clock timing by default. |
| Linux performance counters | Linux x86-64 and ARM64 | Access depends on the host's `perf_event` policy. |
| Apple performance counters | Apple Silicon macOS | Uses private frameworks and requires elevated privileges. |

Professor follows Mojo closely. Let Pixi resolve the compiler version required
by the package; source development uses the version pinned in
[`pixi.toml`](pixi.toml).

Version `0.1` is usable but pre-stable. The core profiling workflow is tested,
while public APIs may change between minor releases. OS performance-counter
APIs should be treated as experimental.

## Project Status

Professor is under active development. Current behavior is covered by tests on
the repository's supported targets, but pre-stable releases may revise public
interfaces as Mojo evolves.

Use [GitHub issues](https://github.com/gsmyridis/professor/issues) for confirmed
bugs and planned work. A failing example should include the Mojo version,
platform, command, and complete error message.

## Acknowledgments

Professor's Apple counter support builds on reverse-engineering work including
[ibireme's `kpc_demo.c`](https://gist.github.com/ibireme/173517c208c7dc333ba962c1f0d67d12).

It also relies on
[Dougall Johnson's Apple Silicon CPU research](https://github.com/dougallj/applecpu).

## License

Professor is available under the [MIT License](LICENSE).
