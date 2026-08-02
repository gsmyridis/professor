from std.ffi import c_int, external_call
from std.sys._libc_errno import get_errno
from std.sys.intrinsics import unlikely
from std.sys.info import size_of

from ._sys import (
    perf_event_enable,
    perf_event_disable,
    perf_event_reset,
    perf_event_id,
    perf_event_read,
)
from ._file import _FileHandle


struct Counter(Movable):
    var _file: _FileHandle
    """The perf-event file handle for this counter, returned by `perf_event_open`.

    When a `Counter` is dropped, this file is dropped, and the kernel
    removes the counter from any group it belongs to.
    """

    var _id: UInt64
    """The unique id assigned to this counter by the kernel."""

    def __init__(out self, *, var unsafe_file: _FileHandle) raises:
        self._file = unsafe_file^
        self._id = 0
        if (
            perf_event_id(self._file._get_raw_fd(), UnsafePointer(to=self._id))
            != 0
        ):
            var err = get_errno()
            raise Error(t"failed to get performance event id: {err}")

    def id(self) -> UInt64:
        """Returns the unique id assigned by the kernel.

        Returns:
            The counter's unique id.
        """
        return self._id

    def enable(mut self) raises:
        """Allow this `Counter` to begin counting its designated event.

        This does not affect whatever value the `Counter` had previously; new
        events add to the current count. To clear a `Counter`, use the
        `reset` method.

        Note that `Group` also has an `enable` method, which enables all
        its member `Counter`s as a single atomic operation.
        """
        if perf_event_enable(self._file._get_raw_fd()) != 0:
            var err = get_errno()
            raise Error(t"failed to enable counter: {err}")

    def disable(mut self) raises:
        """Make this `Counter` stop counting its designated event. Its count is
        unaffected.

        Note that `Group` also has a `disable` method, which disables all its
        member `Counter`s as a single atomic operation.
        """
        if perf_event_disable(self._file._get_raw_fd()) != 0:
            var err = get_errno()
            raise Error(t"failed to disable counter: {err}")

    def reset(mut self) raises:
        """Reset the value of this `Counter` to zero.

        Note that `Group` also has a `reset` method, which resets all its member
        `Counter`s as a single atomic operation.
        """
        if perf_event_reset(self._file._get_raw_fd()) != 0:
            var err = get_errno()
            raise Error(t"failed to reset counter: {err}")

    def read[
        origin: MutOrigin
    ](self, buffer: Span[UInt64, origin]) raises -> Int:
        """Read counting payload into a span.

        Args:
            buffer: The mutable Span to read data into.

        Returns:
            The total amount of data that was read in bytes.

        Raises:
            An error if this file handle is invalid, or if the file read
            returned a failure.
        """

        var fd = self._file._get_raw_fd()
        if fd < 0:
            raise Error("invalid file handle")

        var bytes_read = perf_event_read(
            fd, buffer.unsafe_ptr(), UInt(len(buffer) * size_of[UInt64]())
        )

        if bytes_read < 0:
            var err = get_errno()
            raise Error("Failed to read from file: " + String(err))

        return bytes_read
