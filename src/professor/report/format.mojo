struct ReportColumn(Equatable, ImplicitlyCopyable, Writable):
    """Identity of a selectable profiler report column."""

    comptime Zone = Self(_value=1)
    comptime Site = Self(_value=2)
    comptime Count = Self(_value=3)
    comptime Inclusive = Self(_value=4)
    comptime Exclusive = Self(_value=5)
    comptime InclusiveMin = Self(_value=6)
    comptime InclusiveAverage = Self(_value=7)
    comptime ProcessedData = Self(_value=8)
    comptime Throughput = Self(_value=9)
    comptime InclusivePercentage = Self(_value=10)
    comptime ExclusivePercentage = Self(_value=11)

    var _value: UInt8

    @doc_hidden
    def __init__(out self, *, _value: UInt8):
        self._value = _value

    @staticmethod
    def all() -> List[Self]:
        """Returns every column identity in the default display order."""
        return [
            Self.Zone,
            Self.Site,
            Self.Count,
            Self.Inclusive,
            Self.Exclusive,
            Self.InclusiveMin,
            Self.InclusiveAverage,
            Self.ProcessedData,
            Self.Throughput,
            Self.InclusivePercentage,
            Self.ExclusivePercentage,
        ]

    def name(self) -> StaticString:
        """Returns the column's unscaled display name."""
        if self == Self.Zone:
            return "Zone"
        if self == Self.Site:
            return "Site"
        if self == Self.Count:
            return "Count"
        if self == Self.Inclusive:
            return "Inclusive"
        if self == Self.Exclusive:
            return "Exclusive"
        if self == Self.InclusiveMin:
            return "Inclusive Min."
        if self == Self.InclusiveAverage:
            return "Inclusive / Iter."
        if self == Self.ProcessedData:
            return "Processed Data"
        if self == Self.Throughput:
            return "Throughput"
        if self == Self.InclusivePercentage:
            return "Inclusive (%)"
        if self == Self.ExclusivePercentage:
            return "Exclusive (%)"
        return "Unknown"

    def _is_supported(self) -> Bool:
        return (
            self._value >= Self.Zone._value
            and self._value <= Self.ExclusivePercentage._value
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.name())


struct ReportFormat(Copyable):
    """Formatting settings for the performance report."""

    var _max_decimals: Int
    var _columns: List[ReportColumn]

    def __init__(
        out self,
        *,
        var columns: List[ReportColumn] = ReportColumn.all(),
        max_decimals: Int = 2,
    ):
        """Creates a format with an ordered column selection.

        The list must contain `ReportColumn.Zone` exactly once and no duplicate
        columns. Validation occurs when a report is materialized.
        """
        self._max_decimals = max_decimals
        self._columns = columns^

    def maximum_decimals(self) -> Int:
        return self._max_decimals

    def columns(self) -> List[ReportColumn]:
        """Returns the requested columns in display order."""
        return self._columns.copy()

    def _validated_columns(self) raises -> List[ReportColumn]:
        var columns = self.columns()
        var zone_count = 0
        for i in range(len(columns)):
            ref column = columns[i]
            if not column._is_supported():
                raise Error("unsupported report column")
            if column == ReportColumn.Zone:
                zone_count += 1
            for previous in range(i):
                if column == columns[previous]:
                    raise Error("duplicate report column: ", column)

        if zone_count != 1:
            raise Error("report columns must contain Zone exactly once")
        return columns^
