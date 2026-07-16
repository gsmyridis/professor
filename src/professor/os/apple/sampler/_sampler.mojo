from std.ffi import c_int

from professor.os.apple.config import ConfigBuilder
from professor.os.apple.cpu import Cpu
from professor.os.apple.database import Database
from professor.os.apple.event import Event
from professor.os.apple.kperf import (
    force_all_ctrs_get,
    force_all_ctrs_set,
)
from professor.os.apple.ffi import kperf as ffi_kperf
from professor.os.apple.sampler._thread import ThreadSampler


struct Sampler(Movable):
    var _db: Database
    var _cpu: Cpu
    var _saved_force_all: c_int
    var _released: Bool

    def __init__(out self) raises:
        self._db = Database()
        self._cpu = Cpu(database_name=self._db.name())
        self._saved_force_all = force_all_ctrs_get()
        self._released = False
        force_all_ctrs_set(1)

        # // Verify that the framework's kpep_event stride matches our struct
        # // definition. Apple has changed this struct size across macOS versions;
        # // a mismatch means our repr(C) definition is stale and direct field
        # // access would read corrupt data.
        # if cfg!(any(debug_assertions, feature = "runtime-assertions")) {
        #     verify_event_stride(kpep_vt, db.as_ptr())?;

    def __del__(deinit self):
        if not self._released:
            # Global counting is shared kernel state. Clearing it here would
            # stop other samplers/threads that did not create this lease.
            _ = ffi_kperf.kpc_force_all_ctrs_set(self._saved_force_all)

    def release(mut self) raises:
        if self._released:
            return
        # Global counting is shared kernel state. Clearing it here would stop
        # other samplers/threads that did not create this lease.
        force_all_ctrs_set(self._saved_force_all)
        self._released = True

    def cpu(self) -> Cpu:
        return self._cpu

    def thread[
        E: Event & Movable
    ](self, events: List[E]) raises -> ThreadSampler:
        """Creates a thread-local sampler for typed Apple Silicon events."""
        var builder = ConfigBuilder(self._db)
        builder.force_counters()
        for event in events:
            builder.add_event(self._db.get_event(event))

        var configuration = builder.build()
        return ThreadSampler(configuration^)
