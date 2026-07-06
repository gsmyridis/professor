from professor.apple import Database, ConfigBuilder, PortableEvent, Version
from std.testing import assert_equal


def function_to_measure(n: Int) -> UInt64:
    var total: UInt64 = 0
    for i in range(n):
        total += UInt64(i)
    return total


def measure_function() raises:
    var version = Version()
    print("Version:", version)

    # ===--------------------------------------------------------------===
    # 1. Open the kpep database.
    # ===--------------------------------------------------------------===
    var db = Database()

    # ===--------------------------------------------------------------===
    # 2. Create an empty config builder tied to that database.
    # ===--------------------------------------------------------------===
    var cfg = ConfigBuilder(db)

    # ===--------------------------------------------------------------===
    # 3. Force-counters MUST be called before any add_event on Apple
    #    Silicon. The configurable PMCs are normally owned by powerd;
    #    this flags the config so the registers it produces assume you'll
    #    take ownership in step 7. Skipping this -> error 13
    #    (COUNTERS_NOT_FORCED) from add_event.
    # ===--------------------------------------------------------------===
    cfg.force_counters()

    # ===--------------------------------------------------------------===
    # 4. Add each event. FIXED_CYCLES/FIXED_INSTRUCTIONS pull in the FIXED
    #    class; the other three are general PMU events and pull in
    #    CONFIGURABLE. Each call claims one hardware counter slot - if you
    #    request more CONFIGURABLE events than the M4 has configurable
    #    counters, this starts failing once the slots run out.
    # ===--------------------------------------------------------------===
    var events = [
        PortableEvent.FixedInstructions,
        PortableEvent.FixedCycles,
        PortableEvent.L1DCacheMissLd,
        PortableEvent.CoreActiveCycle,
    ]
    for ev in events:
        var ev_desc = db.get_event(ev)
        cfg.add_event(ev_desc)

    # ===--------------------------------------------------------------===
    # 5. Ask the config which classes ended up active - this answers "is it
    #    FIXED, CONFIGURABLE, or both" without you tracking it by hand.
    #    With these 5 events it'll be FIXED_MASK | CONFIGURABLE_MASK.
    # ===--------------------------------------------------------------===
    var classes = cfg.active_classes()
    print(t"Classes to activate based on config: {classes}")

    # ===--------------------------------------------------------------===
    # 6. Let kpep compute the actual register values (event selector bits
    #    etc.) for FIXED+CONFIGURABLE combined - this is the "configure the
    #    configurable counters" step from before, just done for you instead
    #    of hand-encoding PMU event selectors.
    # ===--------------------------------------------------------------===
    var kpc_count = cfg.counter_count()
    print("KPC count:", kpc_count)
    var counters = cfg.counters()
    assert_equal(kpc_count, len(counters))
    for i in range(kpc_count):
        print(t"KPC_CONFIG[{i}]", counters[i])

    var counter_map = cfg.counter_map()
    print(counter_map)

    # # ===--------------------------------------------------------------===
    # # 7. Take ownership of the configurable counters from powerd - required
    # #    because of step 3. Without this, kpc_set_config below fails.
    # # ===--------------------------------------------------------------===
    # assert_success(kperf.kpc_force_all_ctrs_set(1))

    # # ===--------------------------------------------------------------===
    # # 8. Program the hardware registers for both active classes in one call.
    # # ===--------------------------------------------------------------===
    # assert_success(kperf.kpc_set_config(classes, kpc_config_buf))

    # # ===--------------------------------------------------------------===
    # # 9. Start counting, system-wide, then for this thread specifically.
    # #    Both use the *same* mask here because we want all 5 events
    # #    attributed to this thread - per the earlier answer, thread_classes
    # #    must be a subset of counting_classes or the per-thread numbers are
    # #    meaningless.
    # # ===--------------------------------------------------------------===
    # assert_success(kperf.kpc_set_counting(classes))
    # assert_success(kperf.kpc_set_thread_counting(classes))

    # # ===--------------------------------------------------------------===
    # # 10. kpc_get_thread_counters returns one UInt64 per *absolute hardware
    # #     slot* (all FIXED slots, then all CONFIGURABLE slots) - not one per
    # #     event. kpep_config_kpc_map gives the event-index -> slot-index
    # #     mapping so we know where each of our 5 events landed.
    # # ===--------------------------------------------------------------===
    # var events_count: c_size_t = 0
    # assert_success(
    #     kperf_data.kpep_config_events_count(cfg, UnsafePointer(to=events_count))
    # )

    # var slot_map = alloc(
    #     Layout[c_size_t](count=Int(events_count))
    # ).unsafe_leak()
    # assert_success(
    #     kperf_data.kpep_config_kpc_map(
    #         cfg, slot_map, events_count * UInt(size_of[c_size_t]())
    #     )
    # )

    # var counter_count = kperf.kpc_get_counter_count(classes)
    # var before = alloc(Layout[UInt64](count=Int(counter_count))).unsafe_leak()
    # var after = alloc(Layout[UInt64](count=Int(counter_count))).unsafe_leak()

    # # ===--------------------------------------------------------------===
    # # 11. Snapshot, run the function, snapshot again. These are cumulative
    # #     per-thread counters, so the delta isolates exactly what happened
    # #     between the two reads.
    # # ===--------------------------------------------------------------===
    # assert_success(
    #     kperf.kpc_get_thread_counters(0, UInt32(counter_count), before)
    # )
    # var result = function_to_measure()
    # assert_success(
    #     kperf.kpc_get_thread_counters(0, UInt32(counter_count), after)
    # )
    # print("result:", result)

    # # ===--------------------------------------------------------------===
    # # 12. Report deltas per event, using slot_map[i] to find event i's slot.
    # # ===--------------------------------------------------------------===
    # for i in range(Int(events_count)):
    #     var slot = Int(slot_map[i])
    #     print(event_names[i], ":", after[slot] - before[slot])

    # # ===--------------------------------------------------------------===
    # # 13. Tear down. Leaving classes "on" keeps the PMCs running (and
    # #     withheld from powerd) for the rest of the process's lifetime.
    # # ===--------------------------------------------------------------===
    # assert_success(kperf.kpc_set_thread_counting(0))
    # assert_success(kperf.kpc_set_counting(0))
    # assert_success(kperf.kpc_force_all_ctrs_set(0))
    # kperf_data.kpep_config_free(cfg)
    # kperf_data.kpep_db_free(db)


def main() raises:
    try:
        measure_function()
    except e:
        print(t"error: {e}")
        print("possible fix: run with sudo")
