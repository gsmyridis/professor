from professor.apple.config import Configuration
from professor.apple.kperf import (
    get_counting,
    get_thread_counters,
    set_config,
    set_counting,
    set_thread_counting,
)
from professor.apple.ffi import kperf as ffi_kperf


struct ThreadSampler(Movable):
    """Per-thread performance counter reader.

    Created via [`Sampler::thread`]. You call [`start`](Self::start) to enable
    counting, [`sample`](Self::sample) to read the current raw counter values,
    and [`stop`](Self::stop) to disable counting. A `ThreadSampler` is
    reusable across multiple start/stop cycles.

    Hardware performance counters are thread-local: each CPU core maintains
    separate counter registers, and the kernel tracks per-thread accumulations
    as threads migrate between cores. This means a `ThreadSampler` must be
    used on the thread that created it, which is why it is `!Send + !Sync`.
    """

    var _running: Bool
    var _configuration: Configuration

    var _raw_values: List[UInt64]
    var _event_values: List[UInt64]

    def __init__(out self, var configuration: Configuration):
        self._running = False
        self._configuration = configuration^

        self._raw_values = List[UInt64](
            length=self._configuration.hardware_counter_count,
            fill=0,
        )
        self._event_values = List[UInt64](
            length=len(self._configuration.counter_map),
            fill=0,
        )

    def __del__(deinit self):
        if self._running:
            _ = ffi_kperf.kpc_set_thread_counting(0)

    def is_running(self) -> Bool:
        return self._running

    def event_count(self) -> Int:
        return len(self._configuration.counter_map)

    def event_names(self) -> List[String]:
        return self._configuration.event_names.copy()

    def start(mut self) raises:
        """Programs counters and enables global and per-thread counting."""
        if self._running:
            return

        if len(self._configuration.registers) > 0:
            set_config(
                self._configuration.classes.value(),
                self._configuration.registers,
            )
        var classes = self._configuration.classes.value()
        # Global counting is shared kernel state, not owned by this sampler.
        # Preserve any classes already enabled by this process or another
        # profiler instead of replacing the mask with only our classes.
        set_counting(get_counting() | classes)
        set_thread_counting(classes)
        self._running = True

    def stop(mut self) raises:
        """Disables per-thread counting for this sampler."""
        if not self._running:
            return

        set_thread_counting(0)
        self._running = False

    def sample(mut self) raises -> List[UInt64]:
        """Reads current counter values in the original event order."""
        if not self._running:
            raise Error(
                "thread sampler is not running; call start() before sample()"
            )

        get_thread_counters(
            0,
            UInt32(len(self._raw_values)),
            self._raw_values.unsafe_ptr(),
        )

        for i in range(len(self._configuration.counter_map)):
            var slot = self._configuration.counter_map[i]
            self._event_values[i] = self._raw_values[slot]
        return self._event_values.copy()
