# Professor — ModCon lightning talk

**Length:** 5 minutes hard cap. Script below is ~4:20 spoken at a calm 145 wpm,
which leaves ~40s of slack for the room, a laugh, and a slow slide advance.

**Audience:** Mojo/MAX users, mixed experience. Assume they know what a profiler
is for and nothing about hardware counters.

**Structure:** three features, one payoff each. Zones → counters → repetition
testing. Every slide answers "what does this get me?" before "how does it work?".

**Delivery rules for this talk**

- No live demo. Five minutes has no room for a build. Screenshots of real runs.
- One idea per slide, code blocks ≤ 10 lines, ≥ 24pt.
- Say the number out loud whenever a number is on screen.
- Cut list if you are behind at slide 6: drop slide 5 (linearity), then trim
  slide 8 to the first two sentences.

---

## Slide 1 — Title (0:00 – 0:25)

**On screen**

> # Professor
> ### Where your Mojo program spends its time — and why
> github.com/gsmyridis/professor · *your name / handle*

**Say**

> We write Mojo because we want the machine to go fast. But "my program takes
> 350 milliseconds" doesn't tell you what to fix. Professor is an
> instrumentation profiler for Mojo. You mark the regions you care about, and it
> tells you where the time went — and, with hardware counters, why it went
> there. Three things in five minutes.

---

## Slide 2 — The problem (0:25 – 0:52)

**On screen**

> **Total time** → a score, not a diagnosis
> **Sampling profilers** (Instruments, `perf`) → great, but the labels are
> whatever survived inlining
> **Instrumentation** → *you* name the regions, you get exact per-region numbers

**Say**

> There are two honest ways to get granular numbers. Sampling profilers
> interrupt your program and ask where it is — excellent tools, learn them. But
> the names you get back are whatever survived the optimizer. Instrumentation is
> the other way: you say "this region is called parse", and you get exact counts
> for it, with a label that means something to you. Professor takes the second
> road.

---

## Slide 3 — Feature 1: zones (0:52 – 1:28)

**On screen**

```mojo
comptime Prof = GlobalProfiler[WallClock]

def parse(input: String) -> Int:
    with Prof.zone["parse"]():
        ...

def main() raises:
    Prof.start()
    var count = parse(text)
    Prof.end()
    print(Prof.report())
```

**Say**

> This is the whole API. You declare a profiler once. You wrap a region in a
> zone and give it a name. `start` and `end` bracket the program, and `report`
> prints the table. Zones nest — a zone inside a zone inside a loop is fine, and
> recursion is accounted for correctly. Mark as much or as little as you want:
> one zone around your whole pipeline, or one around every function in it.

---

## Slide 4 — What the report tells you (1:28 – 2:05)

**On screen** — `assets/haversine-profile.png` (full width, cropped to the
table). Callout arrow on the `93.8%` row and on `parse_number`.

**Say**

> This is a real run: a hundred thousand coordinate pairs, parsed from JSON,
> then the haversine distance computed for each. Look at where the time is.
> Parsing is ninety-four percent. The floating-point math — the part everyone
> assumes is the expensive bit — is one point three percent. And because the
> report separates *inclusive* time from *exclusive* time, the time in a zone's
> own body versus its children, it points one level deeper: parsing *numbers*,
> by itself, is twenty-nine percent of the entire program. That's the fix, and
> you can see it without reading a single line of assembly.

---

## Slide 5 — Zones you can't forget to close (2:05 – 2:20)

**On screen**

```mojo
var zone = Prof.zone["hot_loop"]()
...
zone^.close()          # forget this → compile error
```

**Say**

> One Mojo-specific detail I like. A zone handle is a linear value. If you take
> one and don't consume it on every path, the compiler stops you. A forgotten
> close is a build failure, not a silently wrong measurement. Use `with` when
> you can; take the handle when you need to close somewhere else.

*(Cut this slide first if you are behind.)*

---

## Slide 6 — Feature 2: the PMU (2:20 – 3:05)

**On screen**

> Time tells you **where**. Counters tell you **why**.
> cycles · retired instructions · cache misses · branch mispredicts

```mojo
var sampler = Sampler()
var thread = sampler.thread(
    [PortableEvent.Cycles, PortableEvent.Instructions]
)
thread.start()

var before = thread.sample()
work()
var after = thread.sample()
```

**Say**

> Every core has a performance monitoring unit: hardware registers that count
> cycles, retired instructions, cache misses, branch mispredicts. On Apple
> Silicon that lives behind `kperf` — private, undocumented frameworks, the same
> ones Instruments uses. Professor wraps them: owned handles, typed events, and
> the counters come back in the order you asked for them, not in raw hardware
> slot order. You pick events by name, and if this chip doesn't have that event,
> you get an error instead of a wrong number.

---

## Slide 7 — Counters inside your zones (3:05 – 3:35)

**On screen** — one table per component, side by side or stacked:

```text
cycles — total 7000              L1D load misses — total 4200
Zone   Count  Inclusive  %       Zone     Count  Inclusive  %
outer      1       3000  42.9%   scatter     10       4000  95.2%
```

> The cycles-hot zone and the cache-miss-hot zone are **not the same zone**.

**Say**

> Now plug that into the profiler. A metric doesn't have to be one number — mine
> is wall clock, cycles, instructions, and L1 misses at once, so the report
> prints one table per counter. And they disagree, which is the entire point.
> The zone that burns the most cycles is not the zone that misses the cache
> most. My favourite case: a zone that just sleeps dominates the wall-clock
> table and almost vanishes from the cycles table — because counters only
> accumulate while your thread is actually on a core. One table says "this is
> your bottleneck", the other says "this is waiting, not working". Either one
> alone would have lied to you.

---

## Slide 8 — Feature 3: repetition testing (3:35 – 4:10)

**On screen**

```mojo
var tester = RepetitionTester(WallClock(), patience=10)
_ = tester.run[read_file]()
```

```text
Repetition results — 12 repetitions

Statistic      Value
---------  ---------
Minimum    1234000ns
Maximum    1354000ns
Average    1295416ns
```

**Say**

> Last one. Measure a function once and you've measured your machine's mood —
> the scheduler, a cold cache, a noisy neighbour. Those only ever make it
> slower. So run it repeatedly and keep the *minimum*: the closest thing you
> have to the run where nothing went wrong. Professor's repetition tester does
> that, and it stops on its own — `patience=10` means ten consecutive runs
> without a new minimum, not ten runs total. Every counter gets its own minimum,
> maximum, and average, and it redraws live in your terminal while it runs.

---

## Slide 9 — Close (4:10 – 4:25)

**On screen**

> **Today:** zones · reports · repetition testing · Apple Silicon PMU
> **Next:** Linux `perf_event_open` · x86 `rdtsc` · per-zone min/max/variance
> github.com/gsmyridis/professor — pixi run, `-I src`, go

**Say**

> Zones and repetition testing work anywhere Mojo does. The hardware counters
> are Apple Silicon today; Linux `perf_event_open` is next. It's on GitHub,
> it's early, and I would love issues from anyone who profiles something real
> with it. Thank you.

---

## Pre-flight checklist

- [ ] Recapture `assets/haversine-profile.png` at presentation resolution, or
      crop the existing one so the `%` column is legible from the back row.
- [ ] Capture a **real** counters report for slide 7:
      `sudo pixi run example-counters` — the table on the slide is currently
      shaped from the docs, not from a run. Include `blocking_work` in the shot;
      the wall-clock-vs-cycles contrast is the punchline.
- [ ] Capture the repetition tester mid-run (spinner + live table) as a still,
      or a 3-second loop if the venue allows video.
- [ ] Rehearse twice with a timer. Lightning talks overrun on slide 4 — the
      temptation to explain inclusive vs exclusive properly. Don't; the number
      makes the point.
- [ ] Have the repo URL on the title slide *and* the last slide.
