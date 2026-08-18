# Reports

A `Report` is the completed view of one profiling session. It holds the metric
for the full `start()` to `end()` interval, aggregated zone statistics, and the
tables used for display.

Call `report()` only after `end()` and after every zone has closed:

```mojo
Prof.start()
with Prof.zone["work"]():
    work()
Prof.end()

var report = Prof.report()
print(report)
```

Report construction may raise because it validates lifecycle state, selected
columns, metric decomposition, and layout. Printing a completed report does not
repeat that work.

## Reading Columns

The default format selects columns in this order:

| Column | Meaning |
| --- | --- |
| `Zone` | Semantic zone label. |
| `Site` | Source file, line, and column of the call site. |
| `Count` | Number of completed invocations at the site. |
| `Inclusive` | Aggregate metric including nested zones. |
| `Exclusive` | Inclusive metric minus child attribution. |
| `Inclusive Min.` | Smallest inclusive value for one invocation. |
| `Inclusive / Iter.` | Aggregate inclusive value divided by count. |
| `Processed Data` | Aggregate bytes recorded by the site. |
| `Throughput` | Processed data divided by inclusive elapsed time. |
| `Inclusive (%)` | Inclusive value as a percentage of the program total. |
| `Exclusive (%)` | Exclusive value as a percentage of the program total. |

Processed-data columns appear only when at least one zone records bytes.
Throughput appears only for elapsed-time components.

Nested inclusive percentages may overlap. They describe attribution within a
hierarchy and need not add to 100%.

## Selecting Columns

`ReportFormat` controls column selection, order, and numeric precision:

```mojo
from professor import ReportColumn, ReportFormat

var format = ReportFormat(
    columns=[
        ReportColumn.Zone,
        ReportColumn.Count,
        ReportColumn.Inclusive,
        ReportColumn.InclusivePercentage,
    ],
    max_decimals=3,
)
print(Prof.report(format^))
```

The list must contain `ReportColumn.Zone` exactly once. Other columns may not
repeat. Selection changes rendering but does not remove data from
`Report.stats`.

## Units and Precision

Each numeric column chooses one readable unit from all its values. A time
column may render in nanoseconds while another report uses milliseconds; every
row in one column shares that column's unit.

Time and data sizes scale automatically. Data uses decimal SI prefixes. Numbers
group thousands with `,` and use `.` as the decimal separator.

`max_decimals` sets an upper bound, not a requirement to show trailing zeros.
Percentage coloring is enabled for terminals and omitted when output is
redirected.

## Structured Results

Rendering is optional. `Report.total` holds the metric across the program
interval, while `Report.stats` contains `ZoneStatistics` values.

Each statistic exposes:

- `name`
- `loc`
- `count`
- `inclusive`
- `exclusive`
- `inclusive_min`
- `processed_data`

Use these values when another tool should consume the measurements or when a
program needs its own policy for selecting important zones.

## Scalar and Composite Metrics

A scalar instrument produces one table. A flat composite metric produces one
table per field, and each table compares zones against that component's program
total.

For example, an instrument returning elapsed time, cycles, and instructions
creates three tables. The zone with the most elapsed time need not be the zone
with the most cycles.

Field names become stable table identities. [Custom Instruments](custom-instruments.md)
explains the supported scalar families and the flat-composite constraint.

## CSV Output

Tables write standards-compliant CSV to a caller-owned writer. The output
contains headers and cell text but omits terminal-only titles, rules, blanks,
and ANSI color.

```mojo
var tables = Prof.report().tables()
with open("profile.csv", "w") as file:
    tables[0].write_csv_to(file)
```

A composite report has multiple tables. Choose separate files or another
container format so each metric component keeps its own header and unit.

`write_csv_to` accepts a custom one-character separator:

```mojo
tables[0].write_csv_to(file, separator=";")
```

## Empty Reports

When profiling is compiled out, `report()` returns a valid but empty report.
Its total is the metric's zero value, `stats` is empty, and `tables()` returns
no tables.

Use `Prof.is_enabled()` when surrounding code should print a report only in a
profiling build.
