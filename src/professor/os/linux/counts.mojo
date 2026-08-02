struct Count(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """One counter value and its multiplexing timing metadata."""

    var value: UInt64
    var time_enabled: UInt64
    var time_running: UInt64

    def __init__(
        out self,
        value: UInt64,
        time_enabled: UInt64,
        time_running: UInt64,
    ):
        self.value = value
        self.time_enabled = time_enabled
        self.time_running = time_running

    def scaled(self) raises -> Float64:
        """Return the count scaled for time lost to multiplexing."""
        if self.time_running == 0:
            raise Error("cannot scale a counter that did not run")
        return (
            Float64(self.value)
            * Float64(self.time_enabled)
            / Float64(self.time_running)
        )


struct Counts(Movable, Sized):
    """Values from one atomic group read, in requested event order."""

    var _values: List[UInt64]
    var time_enabled: UInt64
    var time_running: UInt64

    def __init__(
        out self,
        var values: List[UInt64],
        time_enabled: UInt64,
        time_running: UInt64,
    ):
        self._values = values^
        self.time_enabled = time_enabled
        self.time_running = time_running

    def __len__(self) -> Int:
        return len(self._values)

    def __getitem__(self, index: Int) -> UInt64:
        """Return the raw value for the event at `index`."""
        return self._values[index]

    def count(self, index: Int) -> Count:
        """Return a value with the group's shared timing metadata."""
        return Count(
            self[index],
            self.time_enabled,
            self.time_running,
        )

    def scaled(self, index: Int) raises -> Float64:
        """Return one value scaled for time lost to multiplexing."""
        return self.count(index).scaled()
