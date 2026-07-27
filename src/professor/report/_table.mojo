from std.sys import stdout


comptime _ESC = "\033["
comptime _BOLD = "\033[1m"


# ===----------------------------------------------------------------------=== #
# Align
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Align(Equatable, ImplicitlyCopyable):
    """Horizontal alignment of a value within its column."""

    var _value: Int

    comptime LEFT = Self(0)
    comptime RIGHT = Self(1)
    comptime CENTER = Self(2)


# ===----------------------------------------------------------------------=== #
# Color
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Color(Equatable, ImplicitlyCopyable, Writable):
    """An ANSI foreground color.

    Writing a color emits the escape sequence that selects it. Selection is
    stateful -- it stays in effect until something clears it -- so writing
    `DEFAULT` restores the terminal's own foreground color:

    `DEFAULT` is ANSI's reset, so it clears every other attribute too, `bold`
    included.
    """

    var _code: Int

    comptime DEFAULT = Self(0)
    comptime BLACK = Self(30)
    comptime RED = Self(31)
    comptime GREEN = Self(32)
    comptime YELLOW = Self(33)
    comptime BLUE = Self(34)
    comptime MAGENTA = Self(35)
    comptime CYAN = Self(36)
    comptime WHITE = Self(37)
    comptime GRAY = Self(90)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(_ESC, self._code, "m")


# ===----------------------------------------------------------------------=== #
# ColorMode
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct ColorMode(Equatable, ImplicitlyCopyable):
    """When a table is allowed to emit ANSI escape sequences."""

    var _value: Int

    comptime AUTO = Self(0)
    """Colorize only when standard output is a terminal."""

    comptime ALWAYS = Self(1)
    comptime NEVER = Self(2)

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
        color: Color = Color.DEFAULT,
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
        align: Align = Align.LEFT,
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


struct Row(Copyable):
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

    def is_blank(self) -> Bool:
        return not self.is_rule and len(self.cells) == 0


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
    """Repeated to fill a rule row's column width."""

    var color: ColorMode

    def __init__(out self):
        self = Self(
            gap="  ",
            show_header=True,
            header_rule=True,
            header_bold=True,
            rule_char="-",
            color=ColorMode.AUTO,
        )


# ===----------------------------------------------------------------------=== #
# Table
# ===----------------------------------------------------------------------=== #


struct Table(Copyable, Writable):
    """A table whose column widths are derived from its contents."""

    var title: String
    """Written above the header, followed by a blank line. Omitted if empty."""

    var columns: List[Column]
    var rows: List[Row]
    var style: TableStyle

    def __init__(out self, var columns: List[Column]):
        self.title = String()
        self.columns = columns^
        self.rows = []
        self.style = TableStyle()

    def __init__(out self, var columns: List[Column], var style: TableStyle):
        self.title = String()
        self.columns = columns^
        self.rows = []
        self.style = style^

    # ===------------------------------------------------------------------=== #
    # Building
    # ===------------------------------------------------------------------=== #

    def add_row(mut self, var cells: List[Cell]):
        """Appends a row. Missing trailing cells render as empty."""
        self.rows.append(Row(cells^))

    def add_text_row(mut self, var texts: List[String]):
        """Appends a row of plainly formatted cells."""
        var cells = List[Cell](capacity=len(texts))
        for ref text in texts:
            cells.append(Cell(text.copy()))
        self.rows.append(Row(cells^))

    def add_rule(mut self):
        self.rows.append(Row.rule())

    def add_blank(mut self):
        self.rows.append(Row())

    # ===------------------------------------------------------------------=== #
    # Rendering
    # ===------------------------------------------------------------------=== #

    def column_widths(self) -> List[Int]:
        """Returns the rendered width of each column."""
        var widths = List[Int](length=len(self.columns), fill=0)
        for i in range(len(self.columns)):
            ref column = self.columns[i]
            widths[i] = column.min_width
            if self.style.show_header:
                widths[i] = max(widths[i], _display_width(column.header))

        for ref row in self.rows:
            if row.is_rule:
                continue
            var count = min(len(row.cells), len(widths))
            for i in range(count):
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

        for ref row in self.rows:
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
            ref column = self.columns[i]
            var align = column.header_align.or_else(column.align)
            if i > 0:
                writer.write(self.style.gap)
            _write_padded(
                writer,
                column.header,
                widths[i],
                align,
                Color.DEFAULT,
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
        # whitespace, whether they end in empty cells or run short.
        var last = -1
        for i in range(min(len(row.cells), len(widths))):
            if row.cells[i].text:
                last = i

        for i in range(last + 1):
            if i > 0:
                writer.write(self.style.gap)
            ref cell = row.cells[i]
            var align = cell.align.or_else(self.columns[i].align)
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


# ===----------------------------------------------------------------------=== #
# Helpers
# ===----------------------------------------------------------------------=== #


def _display_width(text: StringSlice) -> Int:
    """Approximates the terminal width of `text`.

    Codepoints, not bytes: a multi-byte character occupies one column. Wide
    (CJK) and combining characters are still counted as one.
    """
    return text.count_codepoints()


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
    if align == Align.RIGHT:
        left = slack
    elif align == Align.CENTER:
        left = slack // 2

    writer.write(" " * left)

    var styled = use_color and (bold or color != Color.DEFAULT)
    if styled:
        if bold:
            writer.write(_BOLD)
        # Writing DEFAULT here would reset the bold just selected.
        if color != Color.DEFAULT:
            writer.write(color)
    writer.write(text)
    if styled:
        writer.write(Color.DEFAULT)

    if pad_right:
        writer.write(" " * (slack - left))
