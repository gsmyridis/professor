# Repetition Testing

`RepetitionTester` repeatedly measures one function or capturing closure. It
looks for stable component-wise minima, which are useful when occasional
scheduler or system noise makes short measurements slower than their best run.

This is a microbenchmarking tool, not a replacement for profile zones. Use
zones to locate cost in a larger program; use repetition testing to study one
isolated workload under controlled conditions.

## Basic Use

Any Professor `Instrument` can drive a repetition test:

```mojo
from professor import RepetitionTester, WallClock


def work() raises:
    run_workload()


def main() raises:
    var tester = RepetitionTester(
        WallClock(),
        patience=20,
        batch_reps=10,
        max_reps=1_000,
    )
    var results = tester.run(work)
```

`run()` accepts a non-argument function or capturing closure that may raise. A
workload error is propagated with repetition-testing context.

## Stopping Rules

`patience` is the number of consecutive repetitions allowed without a better
minimum. It is not the total number of repetitions.

For a composite metric, improvement in any component resets patience. The
minimum is component-wise, so its fields may come from different repetitions.

`max_reps` is a hard cap. The tester stops when it reaches that cap even if
patience has not expired. Passing no cap allows patience alone to control the
run.

All three limits must be positive when provided.

## Batching

`batch_reps` runs several workload calls between one pair of instrument reads.
The batch total is divided by its repetition count before it is compared with
previous observations.

Batching reduces the share of time spent reading the instrument. It also hides
variation within a batch, so choose the smallest batch that makes measurement
overhead acceptably small.

The final average uses the exact accumulated total divided by the exact test
count. It is not an average of already rounded batch averages.

## Results

`run()` returns `RepetitionResults` with four public fields:

| Field | Meaning |
| --- | --- |
| `test_count` | Number of completed workload calls. |
| `total` | Exact metric accumulated across all calls. |
| `minimum` | Component-wise minimum observation. |
| `maximum` | Component-wise maximum observation. |

The displayed table adds an average derived from `total / test_count`.

On a terminal, current statistics redraw in place with activity status.
Redirected output receives only the final table, which keeps logs stable.

## Choosing a Workload

Keep setup outside the measured function. Prebuild input, reserve storage when
that is not the subject, and make the result observable so optimization cannot
erase the work.

Warm caches, allocators, and JIT-like initialization can change early samples.
Decide whether cold or steady-state behavior answers the question, then build
that state deliberately.

Avoid printing, logging, and unrelated system calls inside the workload. For
very fast functions, increase `batch_reps` or wrap several logical operations
in one call.

## Composite Instruments

A composite instrument searches minima independently across components. This
can reveal that the fastest elapsed run and the fewest-cache-miss run were not
the same observation.

That behavior is deliberate, but it means the returned `minimum` is not a
single physically observed vector. Inspect totals and variability when
relationships between components matter.

Browse `examples/` for the workflow with a counter-capable instrument. Read
[Hardware Counters](hardware-counters.md) before interpreting PMU results.

## When to Stop Trusting the Minimum

A minimum can remove positive interference, but it cannot correct systematic
bias. Compiler optimization, wrong inputs, measurement overhead, thermal state,
and an unrepresentative environment affect every repetition.

Define the question before tuning patience and batches. Stable numbers are
useful only when the experiment matches the performance claim.
