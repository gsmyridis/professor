# Linux perf event implementation status

This document tracks the Linux `perf_event_open` surface implemented by
Professor and the work intentionally left for later. The low-level ABI targets
Linux 7.1's `include/uapi/linux/perf_event.h`. Older kernels accept the shorter
`perf_event_attr.size` values defined alongside the current version.

## Counting FFI

The low-level counting path is implemented:

- `perf_event_attr` layout through `PERF_ATTR_SIZE_VER9`, including `config4`.
- Generic hardware, hardware-cache, and software event constants.
- Portable hardware and hardware-cache `config` encoders, including extended
  PMU type IDs.
- Counting-related attribute controls:
  `disabled`, `inherit`, `pinned`, `exclusive`, `exclude_user`,
  `exclude_kernel`, `exclude_hv`, `exclude_idle`, `inherit_stat`,
  `enable_on_exec`, `exclude_host`, `exclude_guest`, `inherit_thread`, and
  `remove_on_exec`.
- All `read_format` flags and the `PERF_FORMAT_MAX` sentinel.
- `perf_event_open`, enable, disable, reset, refresh, event-ID lookup, and
  group-wide ioctl operation.
- `read(2)` into caller-owned 64-bit storage.
- Stable layouts for a single count with multiplexing times and a grouped
  count containing value/ID pairs.
- Process, CPU, and cgroup syscall selectors.

The recommended single-counter read format is:

```text
PERF_FORMAT_TOTAL_TIME_ENABLED | PERF_FORMAT_TOTAL_TIME_RUNNING
```

It produces `PerfEventCountAndTime`. The recommended group read format is:

```text
PERF_FORMAT_GROUP | PERF_FORMAT_ID |
PERF_FORMAT_TOTAL_TIME_ENABLED | PERF_FORMAT_TOTAL_TIME_RUNNING
```

It produces a `PerfEventGroupReadHeader` followed by `nr`
`PerfEventGroupReadEntry` values. `time_enabled` and `time_running` must be
retained so callers can detect and scale multiplexed counts.

## Counting work above the FFI

These items are not required to access counting through the raw bindings, but
remain necessary for a complete user-facing Linux backend:

| Missing surface | Description |
| --- | --- |
| Owned `Counter` and `Group` types | Manage file-descriptor lifetime, enforce group-leader/member construction, translate `errno`, and expose atomic enable/reset/disable operations. |
| Read parsing and scaling | Allocate group buffers, validate short reads, associate values with event IDs, and scale multiplexed counts without overflowing intermediate arithmetic. |
| PMU discovery | Read `/sys/bus/event_source/devices/*/{type,format,events}` so named core, uncore, and vendor-specific raw events can be configured without hand-encoding values. |
| mmap/RDPMC fast reads | Map `perf_event_mmap_page` and implement its seqlock protocol for syscall-free counter reads where the kernel enables user PMU access. |
| Linux runtime tests | Exercise real opens, groups, multiplexing, and permission failures on x86-64 and AArch64 Linux. Current tests verify portable ABI layouts and pure encodings on macOS. |

## Deferred event modes

| Missing surface | Description |
| --- | --- |
| Breakpoints | `HW_BREAKPOINT_*` types and lengths plus typed `bp_addr`/`bp_len` configuration. |
| Sampling configuration | `PERF_SAMPLE_*`, branch-sampling filters, register masks, transaction flags, `precise_ip`, periods/frequencies, wakeups, and sample-related attribute controls. |
| Ring-buffer records | `perf_event_mmap_page`, `PERF_RECORD_*` payload definitions, memory ordering, wraparound handling, and record decoding. |
| AUX tracing | AUX mmap management, AUX action controls, and processor-trace payload handling. |
| Tracepoint/BPF control | Tracepoint discovery, filters, BPF attachment/query, and output redirection ioctls. |
| Sampling ioctls | Period changes, output selection, pause-output, filter, BPF, and attribute-modification wrappers. |
| Architecture register definitions | x86-64 and AArch64 `sample_regs_user`/`sample_regs_intr` masks, kept out of the common ABI module by design. |

When updating the binding, compare against the tagged kernel UAPI rather than
only the `perf_event_open(2)` man page. The man page can lag new structure
versions and flags.
