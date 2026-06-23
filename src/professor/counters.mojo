@fieldwise_init
struct PerformanceCounters(Copyable, ImplicitlyCopyable, Movable):
    var cycles: Float64
    var branches: Float64
    var missed_branches: Float64
    var instructions: Float64
    var cache_misses: Float64

    @staticmethod
    def zero() -> Self:
        return Self(0.0, 0.0, 0.0, 0.0, 0.0)

    def __sub__(self, other: Self) -> Self:
        return Self(
            self.cycles - other.cycles,
            self.branches - other.branches,
            self.missed_branches - other.missed_branches,
            self.instructions - other.instructions,
            self.cache_misses - other.cache_misses,
        )
