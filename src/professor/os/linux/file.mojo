from std.ffi import c_int, external_call
from std.sys._libc_errno import get_errno


struct _FileHandle(Movable):
    var _fd: c_int
    """The raw file descriptor."""

    def __init__(out self, *, unsafe_fd: c_int):
        self._fd = unsafe_fd

    def __deinit__(deinit self):
        try:
            self.close()
        except:
            pass

    def close(mut self) raises:
        """Closes the file handle.

        Raises:
            If the operation fails.
        """
        if self._fd < 0:
            return

        var result = external_call["close", c_int](c_int(self._fd))

        if result < 0:
            var err = get_errno()
            # Still mark as closed even on error
            self._fd = -1
            raise Error("failed to close file: " + String(err))

        self._fd = -1

    @always_inline
    def _get_raw_fd(self) -> c_int:
        return self._fd
