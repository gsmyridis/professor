struct ReportFormat(Copyable):
    """Numeric formatting captured by a report at construction."""

    var _max_decimals: Int

    def __init__(
        out self,
        *,
        max_decimals: Int = 2,
    ):
        self._max_decimals = max_decimals

    def maximum_decimals(self) -> Int:
        return self._max_decimals
