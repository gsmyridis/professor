struct ReportFormat(Copyable, Defaultable):
    """Locale-like numeric formatting captured by a report at construction."""

    var _thousands_separator: String
    var _decimal_separator: String
    var _maximum_decimals: Int

    def __init__(out self):
        self._thousands_separator = "."
        self._decimal_separator = ","
        self._maximum_decimals = 3

    def __init__(
        out self,
        var thousands_separator: String,
        var decimal_separator: String,
        maximum_decimals: Int = 3,
    ):
        self._thousands_separator = thousands_separator^
        self._decimal_separator = decimal_separator^
        self._maximum_decimals = maximum_decimals

    def thousands_separator(self) -> String:
        return self._thousands_separator.copy()

    def decimal_separator(self) -> String:
        return self._decimal_separator.copy()

    def maximum_decimals(self) -> Int:
        return self._maximum_decimals
