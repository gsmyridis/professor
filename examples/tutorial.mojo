"""Tutorial: counting hardware performance events with kperf and kperfdata.

Start here to understand how everything in ffi/ fits together.

The two private frameworks involved:

  kperf.framework    — KPC: the raw hardware counter interface.
                       Configures which events to count, starts/stops
                       counting globally and per-thread, reads results.

  kperfdata.framework — KPEP: the event database and config builder.
                        Translates human-readable event names such as
                        "FIXED_CYCLES" into the KPCConfig register values
                        that KPC actually programs into hardware.

The pipeline, in order:

  Step 1 — Identify the hardware        (no root)
  Step 2 — Query counter capabilities   (no root)
  Step 3 — Explore the event database   (no root)
  Step 4 — Build a KPC register config  (no root)
  Step 5 — Program hardware and measure (requires sudo)

Run steps 1–4 freely. For step 5 run the binary with `sudo`.
"""

from std.collections import InlineArray
from std.sys import size_of
from std.ffi import c_char, c_int, c_size_t

from professor.apple.ffi.kperf import (
    KPCConfig,
    KPC_MAX_COUNTERS,
    KPC_CLASS_FIXED_MASK,
    KPC_CLASS_CONFIGURABLE_MASK,
    kpc_pmu_version,
    kpc_cpu_string,
    kpc_get_config_count,
    kpc_get_counter_count,
    kpc_force_all_ctrs_set,
    kpc_set_config,
    kpc_set_counting,
    kpc_set_thread_counting,
    kpc_get_thread_counters,
)
from professor.apple.ffi.kperf_data import (
    KPEPDb,
    KPEPConfig,
    KPEPEvent,
    ConstCStringPointer,
    kpep_config_error_desc,
    kpep_db_create,
    kpep_db_free,
    kpep_db_name,
    kpep_db_events_count,
    kpep_db_event,
    kpep_config_create,
    kpep_config_free,
    kpep_config_add_event,
    kpep_config_force_counters,
    kpep_config_kpc_classes,
    kpep_config_kpc_count,
    kpep_config_kpc,
    kpep_config_kpc_map,
    kpep_event_name,
    kpep_event_alias,
)


# ── Helpers ──────────────────────────────────────────────────────────────────


def c_str(ptr: ConstCStringPointer) -> String:
    """Converts a null-terminated C string pointer to a Mojo String."""
    if not ptr:
        return String()
    # ptr is guaranteed non-nil here; try/except satisfies the compiler since
    # Optional.__getitem__ is declared raises even though it cannot fire.
    try:
        return String(unsafe_from_utf8_ptr=ptr[].bitcast[UInt8]())
    except:
        return String()


def find_event(db: KPEPDb.Pointer, names: List[String]) -> KPEPEvent.Pointer:
    """Returns the first event from `names` found in the database, or null."""
    for name in names:
        var ev: KPEPEvent.Pointer = {}
        if (
            kpep_db_event(
                db,
                name.unsafe_ptr().bitcast[c_char](),
                UnsafePointer(to=ev),
            )
            == 0
        ):
            return ev
    return {}


# ── Step 1: Hardware identification ──────────────────────────────────────────
#
# Before anything else, find out what PMU the kernel exposes and which CPU
# string identifies this machine in the KPEP database.


def step1_identify_hardware():
    print("── Step 1: Hardware identification ──")

    # kpc_pmu_version() returns one of the KPC_PMU_* constants.
    # On Apple Silicon this is KPC_PMU_ARM_APPLE (2).
    print("PMU version:", kpc_pmu_version())

    # kpc_cpu_string() works like snprintf: we own the buffer and pass its size.
    # The returned string (e.g. "cpu_7_8_10b282dc_46") is the key used to find
    # the matching .plist under /usr/share/kpep/.
    var buf = InlineArray[UInt8, 64](fill=0)
    var n = kpc_cpu_string(buf.unsafe_ptr().bitcast[c_char](), c_size_t(64))
    if Int(n) > 0:
        print("CPU string:", String(unsafe_from_utf8_ptr=buf.unsafe_ptr()))


# ── Step 2: Counter capabilities ─────────────────────────────────────────────
#
# Each KPC counter class has a fixed number of config registers and counter
# slots that depend on the CPU model. Query these before sizing any buffers.


def step2_counter_capabilities():
    print("\n── Step 2: Counter capabilities ──")

    # On Apple M-series: FIXED has 2 counters, CONFIGURABLE has 6.
    var fixed_cfgs = kpc_get_config_count(KPC_CLASS_FIXED_MASK)
    var fixed_ctrs = kpc_get_counter_count(KPC_CLASS_FIXED_MASK)
    var cfg_cfgs = kpc_get_config_count(KPC_CLASS_CONFIGURABLE_MASK)
    var cfg_ctrs = kpc_get_counter_count(KPC_CLASS_CONFIGURABLE_MASK)

    print(
        "FIXED:        ",
        fixed_cfgs,
        "config registers,",
        fixed_ctrs,
        "counters",
    )
    print("CONFIGURABLE: ", cfg_cfgs, "config registers,", cfg_ctrs, "counters")


# ── Step 3: KPEP event database ───────────────────────────────────────────────
#
# kperfdata.framework ships a per-CPU plist in /usr/share/kpep/ that lists
# every available PMC event and its hardware selector. kpep_db_create loads
# that plist for the running CPU automatically.


def step3_event_database():
    print("\n── Step 3: KPEP event database ──")

    # Passing a null name auto-detects the current CPU.
    var db: KPEPDb.Pointer = {}
    var ret = kpep_db_create({}, UnsafePointer(to=db))
    if ret != 0:
        print("kpep_db_create failed:", kpep_config_error_desc(Int(ret)))
        return

    # Marketing name (e.g. "Apple M4") and total event count.
    var mkt_name: ConstCStringPointer = {}
    _ = kpep_db_name(db, UnsafePointer(to=mkt_name))
    print("CPU marketing name:", c_str(mkt_name))

    var event_count: c_size_t = 0
    _ = kpep_db_events_count(db, UnsafePointer(to=event_count))
    print("Total events in database:", Int(event_count))

    # Look up a specific event by its plist name. Apple Silicon uses
    # "FIXED_CYCLES"; Intel uses "CPU_CLK_UNHALTED.THREAD".
    var cycles_ev = find_event(
        db,
        ["FIXED_CYCLES", "CPU_CLK_UNHALTED.THREAD", "CPU_CLK_UNHALTED.CORE"],
    )
    if cycles_ev:
        var ev_name: ConstCStringPointer = {}
        var ev_alias: ConstCStringPointer = {}
        _ = kpep_event_name(cycles_ev, UnsafePointer(to=ev_name))
        _ = kpep_event_alias(cycles_ev, UnsafePointer(to=ev_alias))
        print("Cycles event:", c_str(ev_name), "  alias:", c_str(ev_alias))

    kpep_db_free(db)


# ── Step 4: Build a KPC register configuration ───────────────────────────────
#
# A KPEPConfig builder takes human-readable event names and produces:
#   - regs:        the KPCConfig register values to write to hardware
#   - counter_map: maps event index → hardware counter slot
#   - classes:     the KPC_CLASS_*_MASK to pass to kpc_set_counting
#
# This step does not touch hardware — it only translates names to numbers.


def step4_build_config():
    print("\n── Step 4: Build a KPC register configuration ──")

    var db: KPEPDb.Pointer = {}
    _ = kpep_db_create({}, UnsafePointer(to=db))

    # Create a config builder tied to this database.
    var cfg: KPEPConfig.Pointer = {}
    _ = kpep_config_create(db, UnsafePointer(to=cfg))

    # force_counters must be called before kpep_config_add_event on Apple Silicon.
    # It marks the config as needing exclusive counter ownership, which also
    # means kpc_force_all_ctrs_set(1) is required later before programming hardware.
    _ = kpep_config_force_counters(cfg)

    # Add events in the order you want them. This order defines the event
    # index used to interpret counter_map later: index 0 = cycles, 1 = instructions.
    var cycles_ev = find_event(db, ["FIXED_CYCLES", "CPU_CLK_UNHALTED.THREAD"])
    var inst_ev = find_event(db, ["FIXED_INSTRUCTIONS", "INST_RETIRED.ANY"])

    if cycles_ev:
        var r = kpep_config_add_event(cfg, UnsafePointer(to=cycles_ev), 0, {})
        print("Added cycles event:", r == 0)
    if inst_ev:
        var r = kpep_config_add_event(cfg, UnsafePointer(to=inst_ev), 0, {})
        print("Added instructions event:", r == 0)

    # Ask KPEP what this config needs from KPC.
    var classes: UInt32 = 0
    var kpc_count: c_size_t = 0
    _ = kpep_config_kpc_classes(cfg, UnsafePointer(to=classes))
    _ = kpep_config_kpc_count(cfg, UnsafePointer(to=kpc_count))
    print("Class mask:", classes, "  KPC register count:", Int(kpc_count))

    # Extract the raw KPCConfig (UInt64) register values to write to hardware.
    var regs = InlineArray[KPCConfig, KPC_MAX_COUNTERS](fill=0)
    _ = kpep_config_kpc(
        cfg,
        regs.unsafe_ptr(),
        c_size_t(Int(kpc_count) * size_of[KPCConfig]()),
    )

    # Extract the event → counter slot mapping.
    # counter_map[0] is the hardware slot for cycles, [1] for instructions, etc.
    # You use this after reading kpc_get_thread_counters to pick the right index.
    # Note: buf_size is sized by KPC_MAX_COUNTERS, not kpc_count — for FIXED events
    # kpc_count is 0 (no config registers) but there are still event slots to map.
    var counter_map = InlineArray[c_size_t, KPC_MAX_COUNTERS](fill=0)
    _ = kpep_config_kpc_map(
        cfg,
        counter_map.unsafe_ptr(),
        c_size_t(KPC_MAX_COUNTERS * size_of[c_size_t]()),
    )
    print("Cycles slot:       ", Int(counter_map[0]))
    print("Instructions slot: ", Int(counter_map[1]))

    kpep_config_free(cfg)
    kpep_db_free(db)


# ── Step 5: Program hardware and measure ─────────────────────────────────────
#
# This step requires sudo because it writes to hardware PMC registers and
# acquires counters from the Power Manager.
#
# The sequence:
#   1. kpc_force_all_ctrs_set(1)   — acquire counters from Power Manager
#   2. kpc_set_config              — write event selectors to hardware
#   3. kpc_set_counting            — start hardware counters (globally)
#   4. kpc_set_thread_counting     — enable per-thread accumulation
#   5. kpc_get_thread_counters     — snapshot before workload
#   6. <workload>
#   7. kpc_get_thread_counters     — snapshot after workload
#   8. subtract + interpret via counter_map


def step5_measure():
    print("\n── Step 5: Measure a workload (requires sudo) ──")

    # Rebuild config (same as step 4).
    var db: KPEPDb.Pointer = {}
    _ = kpep_db_create({}, UnsafePointer(to=db))
    var cfg: KPEPConfig.Pointer = {}
    _ = kpep_config_create(db, UnsafePointer(to=cfg))

    _ = kpep_config_force_counters(cfg)
    var cycles_ev = find_event(db, ["FIXED_CYCLES", "CPU_CLK_UNHALTED.THREAD"])
    var inst_ev = find_event(db, ["FIXED_INSTRUCTIONS", "INST_RETIRED.ANY"])
    if cycles_ev:
        _ = kpep_config_add_event(cfg, UnsafePointer(to=cycles_ev), 0, {})
    if inst_ev:
        _ = kpep_config_add_event(cfg, UnsafePointer(to=inst_ev), 0, {})

    var classes: UInt32 = 0
    var kpc_count: c_size_t = 0
    _ = kpep_config_kpc_classes(cfg, UnsafePointer(to=classes))
    _ = kpep_config_kpc_count(cfg, UnsafePointer(to=kpc_count))

    var regs = InlineArray[KPCConfig, KPC_MAX_COUNTERS](fill=0)
    _ = kpep_config_kpc(
        cfg, regs.unsafe_ptr(), c_size_t(Int(kpc_count) * size_of[KPCConfig]())
    )

    var counter_map = InlineArray[c_size_t, KPC_MAX_COUNTERS](fill=0)
    _ = kpep_config_kpc_map(
        cfg,
        counter_map.unsafe_ptr(),
        c_size_t(KPC_MAX_COUNTERS * size_of[c_size_t]()),
    )

    kpep_config_free(cfg)
    kpep_db_free(db)

    # ── Program hardware ──────────────────────────────────────────────────────

    # Acquire the PMC counters from the Power Manager. Without this,
    # kpc_set_config will fail when force_counters was used.
    if kpc_force_all_ctrs_set(1) != 0:
        print("kpc_force_all_ctrs_set failed — are you running with sudo?")
        return

    # Write the event selector values into the hardware PMC config registers.
    # FIXED counters have no config registers (kpc_count == 0), so this step
    # is only needed for CONFIGURABLE or mixed event sets.
    if Int(kpc_count) > 0:
        if kpc_set_config(classes, regs.unsafe_ptr()) != 0:
            print("kpc_set_config failed")
            _ = kpc_force_all_ctrs_set(0)
            return

    # Start hardware counting globally (all CPUs, all threads).
    if kpc_set_counting(classes) != 0:
        print("kpc_set_counting failed")
        _ = kpc_force_all_ctrs_set(0)
        return

    # Enable per-thread accumulation. Both kpc_set_counting AND
    # kpc_set_thread_counting must include a class for it to appear in
    # kpc_get_thread_counters. The effective classes are their intersection.
    if kpc_set_thread_counting(classes) != 0:
        print("kpc_set_thread_counting failed")
        _ = kpc_force_all_ctrs_set(0)
        return

    # ── Measure ──────────────────────────────────────────────────────────────

    # Snapshot the per-thread counters before the workload.
    # tid=0 means the current thread. buf_count is the number of UInt64 slots,
    # not bytes — use KPC_MAX_COUNTERS to always have enough room.
    var before = InlineArray[UInt64, KPC_MAX_COUNTERS](fill=0)
    _ = kpc_get_thread_counters(
        0, UInt32(KPC_MAX_COUNTERS), before.unsafe_ptr()
    )

    # Workload.
    var sum: UInt64 = 0
    for i in range(1_000_000):
        sum += UInt64(i)

    var after = InlineArray[UInt64, KPC_MAX_COUNTERS](fill=0)
    _ = kpc_get_thread_counters(0, UInt32(KPC_MAX_COUNTERS), after.unsafe_ptr())

    # counter_map[i] is the hardware counter slot assigned to event i.
    # Subtract before from after at that slot to get the delta.
    var cycles = after[Int(counter_map[0])] - before[Int(counter_map[0])]
    var instructions = after[Int(counter_map[1])] - before[Int(counter_map[1])]

    print("Workload sum (prevents optimisation away):", sum)
    print("Cycles:      ", cycles)
    print("Instructions:", instructions)
    if cycles > 0:
        print("IPC:         ", Float64(instructions) / Float64(cycles))

    # ── Cleanup ───────────────────────────────────────────────────────────────
    # Release counters back to the Power Manager and stop counting.
    # Skipping this leaves the system in a modified state until reboot.
    _ = kpc_set_counting(0)
    _ = kpc_set_thread_counting(0)
    _ = kpc_force_all_ctrs_set(0)


def main():
    step1_identify_hardware()
    step2_counter_capabilities()
    step3_event_database()
    step4_build_config()
    step5_measure()
