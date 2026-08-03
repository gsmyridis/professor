from .token import CounterToken


struct Count(Equatable, ImplicitlyCopyable, RegisterPassable, Writable):
    """One counter value and its multiplexing timing metadata."""

    var value: UInt64
    """Count raw value."""

    var time_enabled: UInt64
    """Total time the counter was enabled."""

    var time_running: UInt64
    """Total time the counter was running."""

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


struct Counts(Copyable, Sized):
    """Values from one atomic group read, addressable by counter token."""

    var _tokens: List[CounterToken]
    var _values: List[UInt64]
    var time_enabled: UInt64
    var time_running: UInt64

    def __init__(
        out self,
        var tokens: List[CounterToken],
        var values: List[UInt64],
        time_enabled: UInt64,
        time_running: UInt64,
    ):
        self._tokens = tokens^
        self._values = values^
        self.time_enabled = time_enabled
        self.time_running = time_running

    def __len__(self) -> Int:
        return len(self._values)

    def __getitem__(self, index: Int) -> UInt64:
        """Return the raw value for the event at `index`."""
        return self._values[index]

    def __getitem__(self, token: CounterToken) raises -> UInt64:
        """Return the raw value belonging to `token`."""
        var index = self._index_of(token)
        if not index:
            raise Error("counter token is not present in these counts")
        return self._values[index.value()]

    def _index_of(self, token: CounterToken) -> Optional[Int]:
        for i in range(len(self._tokens)):
            if self._tokens[i] == token:
                return i
        return None

    def count(self, index: Int) -> Count:
        """Return a value with the group's shared timing metadata."""
        return Count(
            self[index],
            self.time_enabled,
            self.time_running,
        )

    def count(self, token: CounterToken) raises -> Count:
        """Return the token's value with the group's timing metadata."""
        return Count(
            self[token],
            self.time_enabled,
            self.time_running,
        )

    def scaled(self, index: Int) raises -> Float64:
        """Return one value scaled for time lost to multiplexing."""
        return self.count(index).scaled()

    def scaled(self, token: CounterToken) raises -> Float64:
        """Return the token's value scaled for multiplexing."""
        return self.count(token).scaled()
