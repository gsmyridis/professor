from std.sys import stdout


comptime _ESC = "\033["
comptime _BOLD = "\033[1m"

comptime _SPACE = " "
comptime _DOUBLE_SPACE = _SPACE * 2


# ===----------------------------------------------------------------------=== #
# Align
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Align(Equatable, ImplicitlyCopyable):
    """Horizontal alignment of a value within its column."""

    var _value: Int

    comptime Left = Self(0)
    """Align text to the left."""
    comptime Right = Self(1)
    """Align text to the right."""
    comptime Center = Self(2)
    """Align text to the center."""


# ===----------------------------------------------------------------------=== #
# Color
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Color(Equatable, ImplicitlyCopyable, Writable):
    """An ANSI foreground color.

    Writing a color emits the escape sequence that selects it. Selection is
    stateful -- it stays in effect until something clears it -- so writing
    `Default` restores the terminal's own foreground color. `Default` is
    ANSI's reset, so it clears every other attribute too, `bold` included.
    """

    var _code: Int

    comptime Default = Self(0)
    comptime Black = Self(30)
    comptime Red = Self(31)
    comptime Green = Self(32)
    comptime Yellow = Self(33)
    comptime Blue = Self(34)
    comptime Magenta = Self(35)
    comptime Cyan = Self(36)
    comptime White = Self(37)
    comptime Gray = Self(90)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(_ESC, self._code, "m")


# ===----------------------------------------------------------------------=== #
# ColorMode
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct ColorMode(Equatable, ImplicitlyCopyable):
    """When a table is allowed to emit ANSI escape sequences."""

    var _value: Int

    comptime Auto = Self(0)
    """Colorize only when standard output is a terminal."""

    comptime Always = Self(1)
    comptime Never = Self(2)

    def enabled(self) -> Bool:
        if self._value == 1:
            return True
        if self._value == 2:
            return False
        return stdout.isatty()


# ===----------------------------------------------------------------------=== #
# Cell
# ===----------------------------------------------------------------------=== #


struct Cell(Copyable):
    """One rendered value, with the presentation attributes it carries."""

    var text: String
    """The already-formatted content. Must not contain escape sequences."""

    var color: Color
    var bold: Bool

    var align: Optional[Align]
    """Overrides the column's alignment when set."""

    def __init__(
        out self,
        var text: String,
        *,
        color: Color = Color.Default,
        bold: Bool = False,
        align: Optional[Align] = None,
    ):
        self.text = text^
        self.color = color
        self.bold = bold
        self.align = align

    def width(self) -> Int:
        return _display_width(self.text)


# ===----------------------------------------------------------------------=== #
# Column
# ===----------------------------------------------------------------------=== #


struct Column(Copyable):
    """A column's header and the default presentation of its cells."""

    var header: String
    var align: Align
    var min_width: Int

    var header_align: Optional[Align]
    """Overrides `align` for the header cell when set."""

    def __init__(
        out self,
        var header: String,
        *,
        align: Align = Align.Left,
        min_width: Int = 0,
        header_align: Optional[Align] = None,
    ):
        self.header = header^
        self.align = align
        self.min_width = min_width
        self.header_align = header_align


# ===----------------------------------------------------------------------=== #
# Row
# ===----------------------------------------------------------------------=== #


struct Row(Copyable, Defaultable):
    """A line of the table body: cells, a horizontal rule, or a blank line."""

    var cells: List[Cell]
    var is_rule: Bool

    def __init__(out self, var cells: List[Cell]):
        self.cells = cells^
        self.is_rule = False

    def __init__(out self):
        """Constructs a blank row, rendered as an empty line."""
        self.cells = []
        self.is_rule = False

    @staticmethod
    def rule() -> Self:
        """Constructs a horizontal rule spanning every column."""
        var row = Self()
        row.is_rule = True
        return row^

    @staticmethod
    def blank() -> Self:
        """Constructs a blank row, rendered as an empty line."""
        return Self()

    def is_blank(self) -> Bool:
        """Returns true if the row is blank."""
        return not self.is_rule and self.count_cells() == 0

    def count_cells(self) -> Int:
        """Returns the number of cells the row contains."""
        return len(self.cells)


# ===----------------------------------------------------------------------=== #
# TableStyle
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct TableStyle(Copyable, Defaultable):
    """Presentation knobs shared by every row of a table."""

    var gap: String
    """Written between adjacent columns."""

    var show_header: Bool
    var header_rule: Bool
    var header_bold: Bool

    var rule_char: String
    """Repeated to fill a rule row's column width.

    Must be exactly one column wide: it is repeated once per column of width,
    so a longer string overshoots and a rule stops lining up with its table.
    """

    var color: ColorMode

    def __init__(out self):
        self = Self(
            gap=_DOUBLE_SPACE,
            show_header=True,
            header_rule=True,
            header_bold=True,
            rule_char="-",
            color=ColorMode.Auto,
        )


# ===----------------------------------------------------------------------=== #
# Table
# ===----------------------------------------------------------------------=== #


struct Table(Copyable, Writable):
    """A table whose column widths are derived from its contents.

    The columns are fixed at construction and rows only arrive through
    `add_row` and friends, which reject any row that does not carry one cell
    per column. Rendering can therefore index a row by column without
    re-checking its shape.
    """

    var title: String
    """Written above the header, followed by a blank line."""

    var style: TableStyle
    """Table style metadata."""

    var _columns: List[Column]
    """Definition of column headers and style metadata."""

    var _rows: List[Row]
    """Collection of table rows. Private: rendering relies on every row
    carrying exactly one cell per column."""

    def __init__(
        out self,
        var title: String,
        var columns: List[Column],
        var style: TableStyle,
    ):
        self.title = title^
        self.style = style^
        self._columns = columns^
        self._rows = []

    # ===------------------------------------------------------------------=== #
    # Building
    # ===------------------------------------------------------------------=== #

    def add_row(mut self, var cells: List[Cell]) raises:
        """Appends a row, which must carry one cell per column.

        Cells may be empty; trailing empty ones are not rendered, so a row
        that only fills its first column costs nothing but the padding.

        Raises if the row is the wrong width. This is the only place the shape
        is checked, which is why rendering can stay non-raising.
        """
        _check_row_width(len(cells), len(self._columns))
        self._rows.append(Row(cells^))

    def add_text_row(mut self, var texts: List[String]) raises:
        """Appends a row of plainly formatted cells, one per column."""
        var cells = List[Cell](capacity=len(texts))
        for ref text in texts:
            cells.append(Cell(text.copy()))
        self.add_row(cells^)

    def add_rule(mut self):
        self._rows.append(Row.rule())

    def add_blank(mut self):
        self._rows.append(Row.blank())

    # ===------------------------------------------------------------------=== #
    # Inspection
    # ===------------------------------------------------------------------=== #

    def num_columns(self) -> Int:
        """Returns the number of columns the table was built with."""
        return len(self._columns)

    def column(self, index: Int) -> Column:
        """Returns a copy of the column definition at `index`."""
        return self._columns[index].copy()

    # ===------------------------------------------------------------------=== #
    # Rendering
    # ===------------------------------------------------------------------=== #

    def column_widths(self) -> List[Int]:
        """Returns the rendered width of each column."""
        var widths = List[Int](length=len(self._columns), fill=0)

        for i in range(len(self._columns)):
            ref column = self._columns[i]
            widths[i] = column.min_width
            if self.style.show_header:
                widths[i] = max(widths[i], _display_width(column.header))

        for ref row in self._rows:
            # Rules and blanks carry no cells by construction; every other row
            # came through `add_row`, so it has one cell per column.
            if row.is_rule or row.is_blank():
                continue
            for i in range(len(widths)):
                widths[i] = max(widths[i], row.cells[i].width())

        return widths^

    def write_to(self, mut writer: Some[Writer]):
        var widths = self.column_widths()
        var use_color = self.style.color.enabled()

        if self.title:
            writer.write(self.title, "\n\n")
        if self.style.show_header:
            self._write_header(writer, widths, use_color)
        if self.style.header_rule:
            self._write_rule(writer, widths)

        for ref row in self._rows:
            if row.is_blank():
                writer.write("\n")
            elif row.is_rule:
                self._write_rule(writer, widths)
            else:
                self._write_row(writer, row, widths, use_color)

    def _write_header(
        self, mut writer: Some[Writer], widths: List[Int], use_color: Bool
    ):
        var last = len(widths) - 1
        for i in range(len(widths)):
            ref column = self._columns[i]
            var align = column.header_align.or_else(column.align)
            if i > 0:
                writer.write(self.style.gap)
            _write_padded(
                writer,
                column.header,
                widths[i],
                align,
                Color.Default,
                self.style.header_bold and use_color,
                use_color,
                pad_right=i != last,
            )
        writer.write("\n")

    def _write_rule(self, mut writer: Some[Writer], widths: List[Int]):
        for i in range(len(widths)):
            if i > 0:
                writer.write(self.style.gap)
            writer.write(self.style.rule_char * widths[i])
        writer.write("\n")

    def _write_row(
        self,
        mut writer: Some[Writer],
        row: Row,
        widths: List[Int],
        use_color: Bool,
    ):
        # Stop after the last non-empty cell so rows never carry trailing
        # whitespace when they end in empty cells.
        var last = -1
        for i in range(row.count_cells()):
            if row.cells[i].text:
                last = i

        for i in range(last + 1):
            if i > 0:
                writer.write(self.style.gap)
            ref cell = row.cells[i]
            var align = cell.align.or_else(self._columns[i].align)
            _write_padded(
                writer,
                cell.text,
                widths[i],
                align,
                cell.color,
                cell.bold,
                use_color,
                pad_right=i != last,
            )
        writer.write("\n")

    # ===------------------------------------------------------------------=== #
    # CSV serialization
    # ===------------------------------------------------------------------=== #

    def write_csv_to(
        self, mut writer: Some[Writer], *, separator: String = ","
    ):
        """Writes the table as CSV to `writer`.

        CSV contains column headers and cell text. Terminal-only presentation
        such as the title, rules, blank rows, alignment, and color is omitted.
        Fields are quoted when required and embedded quotes are doubled.
        """
        for column_index in range(len(self._columns)):
            if column_index > 0:
                writer.write(separator)
            _write_csv_field(
                writer, self._columns[column_index].header, separator
            )
        writer.write("\r\n")

        for ref row in self._rows:
            if row.is_rule or row.is_blank():
                continue

            for column_index in range(len(self._columns)):
                if column_index > 0:
                    writer.write(separator)
                _write_csv_field(
                    writer, row.cells[column_index].text, separator
                )
            writer.write("\r\n")


# ===----------------------------------------------------------------------=== #
# Helpers
# ===----------------------------------------------------------------------=== #


def _check_row_width(cells: Int, columns: Int) raises:
    """Raises unless a row carries exactly one cell per column."""
    if cells != columns:
        raise Error(
            t"a table row must carry one cell per column: got {cells}"
            t" cell(s) for {columns} column(s)"
        )


def _display_width(text: StringSlice) -> Int:
    """Approximates the terminal width of `text`.

    Codepoints, not bytes: a multi-byte character occupies one column. Wide
    (CJK) and combining characters are still counted as one.
    """
    return text.count_codepoints()


def _write_csv_field(
    mut writer: Some[Writer], text: StringSlice, separator: StringSlice
):
    var needs_quotes = (
        text.find(separator) != -1
        or text.find('"') != -1
        or text.find("\r") != -1
        or text.find("\n") != -1
    )
    if needs_quotes:
        writer.write('"', text.replace('"', '""'), '"')
    else:
        writer.write(text)


def _write_padded(
    mut writer: Some[Writer],
    text: StringSlice,
    width: Int,
    align: Align,
    color: Color,
    bold: Bool,
    use_color: Bool,
    *,
    pad_right: Bool,
):
    var slack = max(0, width - _display_width(text))
    var left = 0
    if align == Align.Right:
        left = slack
    elif align == Align.Center:
        left = slack // 2

    writer.write(_SPACE * left)

    var styled = use_color and (bold or color != Color.Default)
    if styled:
        if bold:
            writer.write(_BOLD)
        # Writing Default here would reset the bold just selected.
        if color != Color.Default:
            writer.write(color)
    writer.write(text)
    if styled:
        writer.write(Color.Default)

    if pad_right:
        writer.write(_SPACE * (slack - left))
