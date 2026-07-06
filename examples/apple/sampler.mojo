from std.benchmark import black_box
from std.time import perf_counter_ns

from professor.apple import Sampler, PortableEvent, ThreadSampler


def compute_baseline_delta(mut thread_sampler: ThreadSampler) raises -> List[UInt64]:
    var baseline_before = thread_sampler.sample()
    var baseline_after = thread_sampler.sample()
    var baseline_delta = baseline_before.copy()
    for i in range(len(baseline_before)):
        baseline_delta[i] = baseline_after[i] - baseline_before[i]
    return baseline_delta^

def main() raises:
    var iterations = black_box(100)
    var sampler = Sampler()
    var thread_sampler = sampler.thread(
        [PortableEvent.Cycles, PortableEvent.Instructions]
    )

    thread_sampler.start()

    var time_before = perf_counter_ns()
    print(compute_baseline_delta(thread_sampler))
    print(compute_baseline_delta(thread_sampler))
    print(compute_baseline_delta(thread_sampler))
    print(compute_baseline_delta(thread_sampler))
    var time_after = perf_counter_ns()
    print("Time:", (time_after - time_before) / 4)


    var result = 0
    var work_before = thread_sampler.sample()
    for i in range(iterations):
        result = black_box(result + i)
    var work_after = thread_sampler.sample()

    var work_delta = work_before.copy()
    for i in range(len(work_before)):
        work_delta[i] = work_after[i] - work_before[i]
    print(work_delta)

    # thread_sampler.stop()

    # var event_names = thread_sampler.event_names()
    # for i in range(thread_sampler.event_count()):
    #     var baseline_delta = Int(baseline_after[i] - baseline_before[i])
    #     var work_delta = Int(work_after[i] - work_before[i])
    #     var net_delta = work_delta - baseline_delta
    #     print(event_names[i], " total:", net_delta)
    #     print(
    #         event_names[i],
    #         " per iteration:",
    #         net_delta // iterations,
    #     )
