# Professor Documentation

The main [README](../README.md) takes a new user from installation to an
interpreted profile. These guides continue from that foundation without
turning the front page into an API manual.

## Profiling

- [Profiling Zones](profiling-zones.md) explains profiler ownership, lifecycle,
  nesting, explicit closure, indexed zones, processed data, and disabled builds.
- [Reports](reports.md) covers columns, units, formatting, structured results,
  composite metrics, table styling, and CSV output.

## Instruments

- [Custom Instruments](custom-instruments.md) shows how cumulative readings
  become scalar or composite zone metrics.
- [Hardware Counters](hardware-counters.md) covers the public Linux and Apple
  Silicon wrappers, their permissions, and their measurement costs.

## Benchmarking

- [Repetition Testing](repetition-testing.md) explains stable-minimum searches
  for functions and capturing closures.

## Examples

Browse `examples/` for complete programs covering zone profiling, repetition
testing, and platform performance counters.
