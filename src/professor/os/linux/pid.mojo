@fieldwise_init
struct ProcessId(ImplicitlyCopyable, RegisterPassable, Writable):

    var id: Int

    comptime All = Self(-1)
    """All processes."""

    comptime Calling = Self(0)
    """Calling process."""
