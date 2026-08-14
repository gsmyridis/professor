from std.testing import assert_equal, assert_false, assert_true, TestSuite

from professor.report.table import (
    Align,
    Cell,
    Color,
    ColorMode,
    Column,
    Row,
    Table,
    TableStyle,
)


def _plain(var columns: List[Column]) -> Table:
    """Builds a table with colors disabled, so output is deterministic."""
    var table = Table(String(), columns^, TableStyle())
    table.style.color = ColorMode.Never
    return table^


# ===----------------------------------------------------------------------=== #
# Widths and alignment
# ===----------------------------------------------------------------------=== #


def test_column_width_is_max_of_header_and_cells() raises:
    var table = _plain([Column("A"), Column("BB")])
    table.add_text_row(["longer", "x"])
    table.add_text_row(["x", "wider!"])

    var widths = table.column_widths()
    assert_equal(widths[0], 6)
    assert_equal(widths[1], 6)


def test_min_width_widens_a_narrow_column() raises:
    var table = _plain([Column("A", min_width=10)])
    table.add_text_row(["x"])
    assert_equal(table.column_widths()[0], 10)


def test_hidden_header_does_not_reserve_width() raises:
    var table = _plain([Column("a-long-header")])
    table.style.show_header = False
    table.add_text_row(["x"])
    assert_equal(table.column_widths()[0], 1)


def test_alignment_places_padding() raises:
    var table = _plain(
        [
            Column("L", align=Align.Left, min_width=5),
            Column("R", align=Align.Right, min_width=5),
            Column("C", align=Align.Center, min_width=5),
            Column("end"),
        ]
    )
    table.style.show_header = False
    table.style.header_rule = False
    table.add_text_row(["x", "x", "x", "|"])

    assert_equal(
        String(table), "x    " + "  " + "    x" + "  " + "  x  " + "  |\n"
    )


def test_cell_alignment_overrides_the_column() raises:
    var table = _plain(
        [Column("H", align=Align.Right, min_width=4), Column("")]
    )
    table.style.show_header = False
    table.style.header_rule = False
    var cells = List([Cell("x", align=Align.Left), Cell("|")])
    table.add_row(cells^)
    assert_equal(String(table), "x     |\n")


def test_header_alignment_can_differ_from_the_column() raises:
    var table = _plain(
        [Column("H", align=Align.Right, header_align=Align.Left, min_width=4)]
    )
    table.style.header_rule = False
    table.add_text_row(["x"])
    assert_equal(String(table), "H\n   x\n")


def test_width_counts_codepoints_not_bytes() raises:
    var table = _plain([Column("h"), Column("")])
    table.style.show_header = False
    table.style.header_rule = False
    # "µs" is three bytes but two columns wide.
    table.add_text_row(["µs", "|"])
    table.add_text_row(["abc", "|"])
    assert_equal(table.column_widths()[0], 3)
    assert_equal(String(table), "µs   |\nabc  |\n")


# ===----------------------------------------------------------------------=== #
# Rows
# ===----------------------------------------------------------------------=== #


def test_trailing_empty_cells_are_not_rendered() raises:
    var table = _plain([Column("AAA"), Column("BBB")])
    table.style.header_rule = False
    table.add_text_row(["x", ""])
    assert_equal(String(table), "AAA  BBB\nx\n")


def test_blank_row_emits_an_empty_line() raises:
    var table = _plain([Column("A", min_width=4)])
    table.style.show_header = False
    table.style.header_rule = False
    table.add_text_row(["x"])
    table.add_blank()
    table.add_text_row(["y"])
    assert_equal(String(table), "x\n\ny\n")


def test_rule_spans_every_column() raises:
    var table = _plain([Column("AA"), Column("B")])
    table.style.show_header = False
    table.style.header_rule = False
    table.add_text_row(["xx", "y"])
    table.add_rule()
    assert_equal(String(table), "xx  y\n--  -\n")


def test_rule_character_is_configurable() raises:
    var table = _plain([Column("AA", min_width=2)])
    table.style.show_header = False
    table.style.header_rule = False
    table.style.rule_char = "="
    table.add_rule()
    assert_equal(String(table), "==\n")


def test_gap_is_configurable() raises:
    var table = _plain([Column("A"), Column("B")])
    table.style.show_header = False
    table.style.header_rule = False
    table.style.gap = " | "
    table.add_text_row(["x", "y"])
    assert_equal(String(table), "x | y\n")


def test_header_rule_follows_the_header() raises:
    var table = _plain([Column("Zone"), Column("N", align=Align.Right)])
    table.add_text_row(["parse", "10"])
    assert_equal(String(table), "Zone    N\n-----  --\nparse  10\n")


def test_title_precedes_the_header() raises:
    var table = _plain([Column("A")])
    table.title = "cycles — total 7000"
    table.add_text_row(["x"])
    assert_equal(String(table), "cycles — total 7000\n\nA\n-\nx\n")


def test_empty_title_is_omitted() raises:
    var table = _plain([Column("A")])
    table.add_text_row(["x"])
    assert_equal(String(table), "A\n-\nx\n")


def test_title_does_not_affect_column_width() raises:
    var table = _plain([Column("A")])
    table.title = "a very long title indeed"
    table.add_text_row(["x"])
    assert_equal(table.column_widths()[0], 1)


def test_last_column_has_no_trailing_padding() raises:
    var table = _plain([Column("Wide header")])
    table.add_text_row(["x"])
    for line in String(table).splitlines():
        assert_false(line.endswith(" "))


# ===----------------------------------------------------------------------=== #
# Color
# ===----------------------------------------------------------------------=== #


def test_color_never_strips_escapes() raises:
    var table = _plain([Column("A")])
    var cells = List([Cell("x", color=Color.Red, bold=True)])
    table.add_row(cells^)
    assert_equal(String(table), "A\n-\nx\n")


def test_color_always_wraps_only_the_text() raises:
    var table = Table(
        String(), [Column("A", align=Align.Right, min_width=3)], TableStyle()
    )
    table.style.color = ColorMode.Always
    table.style.show_header = False
    table.style.header_rule = False
    var cells = List([Cell("x", color=Color.Red)])
    table.add_row(cells^)
    # Padding stays outside the escape sequence.
    assert_equal(String(table), "  \033[31mx\033[0m\n")


def test_color_does_not_affect_column_width() raises:
    var table = Table(String(), [Column("A")], TableStyle())
    table.style.color = ColorMode.Always
    var cells = List([Cell("x", color=Color.Green, bold=True)])
    table.add_row(cells^)
    assert_equal(table.column_widths()[0], 1)


def test_default_color_emits_no_escape() raises:
    var table = Table(String(), [Column("A")], TableStyle())
    table.style.color = ColorMode.Always
    table.style.header_bold = False
    table.add_text_row(["x"])
    assert_true(String(table).find("\033[") == -1)


def test_writing_default_restores_the_terminal_color() raises:
    # The obvious way to close a color outside a table has to actually work.
    assert_equal(String(Color.Red), "\033[31m")
    assert_equal(String(Color.Default), "\033[0m")


def test_bold_without_a_color_is_not_reset_before_the_text() raises:
    # DEFAULT is ANSI's reset, so emitting it after selecting bold would
    # cancel the bold.
    var table = Table(String(), [Column("A")], TableStyle())
    table.style.color = ColorMode.Always
    table.style.show_header = False
    table.style.header_rule = False
    var cells = List([Cell("x", bold=True)])
    table.add_row(cells^)
    assert_equal(String(table), "\033[1mx\033[0m\n")


def test_header_is_bold_by_default() raises:
    var table = Table(String(), [Column("A")], TableStyle())
    table.style.color = ColorMode.Always
    table.style.header_rule = False
    assert_equal(String(table), "\033[1mA\033[0m\n")


def test_header_bold_can_be_turned_off() raises:
    var table = Table(String(), [Column("A")], TableStyle())
    table.style.color = ColorMode.Always
    table.style.header_rule = False
    table.style.header_bold = False
    assert_equal(String(table), "A\n")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
