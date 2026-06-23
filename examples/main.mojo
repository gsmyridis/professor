from professor.apple.ffi import kperf
from std.collections import InlineArray


comptime WORKLOAD_ITERATIONS = 1_000_000


def run_workload(iterations: Int) -> UInt64:
    """Runs a deterministic integer workload and returns its checksum."""
    var checksum = UInt64(1)
    for i in range(iterations):
        checksum = (
            checksum * UInt64(1_664_525) + UInt64(i) + UInt64(1_013_904_223)
        ) % UInt64(4_294_967_291)
    return checksum


def main() raises:
    var buffer = InlineArray[Int8, 32](fill=0)
    var pmu_version = kperf.kpc_pmu_version()
    _ = kperf.kpc_cpu_string(buffer.unsafe_ptr(), UInt(len(buffer)))
    var string = String(
        unsafe_from_utf8_ptr=buffer.unsafe_ptr().bitcast[UInt8]()
    )

    print(pmu_version)
    print(string)

    # var events = AppleEvents()
    # if not events.setup(libs):
    #     print("Failed to configure Apple performance counters.")
    #     print("Run this demo with sufficient privileges on macOS.")
    #     return

    # var before = events.get(libs)
    # var checksum = run_workload(WORKLOAD_ITERATIONS)
    # var after = events.get(libs)
    # var delta = after - before

    # print("checksum:", checksum)
    # print("cycles:", delta.cycles)
    # print("instructions:", delta.instructions)
    # print("branches:", delta.branches)
    # print("branch misses:", delta.missed_branches)
    # print("cache misses:", delta.cache_misses)
