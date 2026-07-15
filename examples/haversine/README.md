# Haversine

This example parses generated coordinate pairs and computes their average
haversine distance with a small Mojo JSON parser.

Generate an input file:

```sh
pixi run -e examples haversine-generate \
  10000 --radius 6372.8 --output examples/haversine/data/pairs.json
```

Check the generated result with Python:

```sh
pixi run -e examples haversine-calculate examples/haversine/data/pairs.json
```

Run the Mojo version from the repository root:

```sh
pixi run -e examples haversine-profile examples/haversine/data/pairs.json
```

Run its parser tests:

```sh
pixi run -e examples test-haversine-parser
```

`parser.mojo` keeps the Rust example's `Token`, `Tokenizer`, `Value`, and
`Parser` structure. Recursive children use `OwnedPointer[Value]`, which is the
explicit indirection required for a recursively owned value tree in Mojo.

The executable uses `professor.profile.Profiler` with a wall clock to report
the full parse, every recursive `parse_value` call, the complete computation,
and every individual haversine calculation.
