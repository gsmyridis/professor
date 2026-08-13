from std.os import remove
from std.pathlib import Path
from std.tempfile import gettempdir
from std.testing import assert_equal, TestSuite

from professor.report.table import Column, Table, TableStyle


def _table(var columns: List[Column]) -> Table:
    return Table(String(), columns^, TableStyle())


def test_writes_header_and_complete_rows() raises:
    var table = _table([Column("Name"), Column("Value"), Column("Note")])
    table.add_text_row(["alpha", "1", ""])

    var output = String()
    table.write_csv_to(output)

    assert_equal(output, "Name,Value,Note\r\nalpha,1,\r\n")


def test_quotes_special_fields() raises:
    var table = _table([Column("Name, quoted"), Column("Note")])
    table.add_text_row(["a,b", 'said "hello"'])
    table.add_text_row(["plain", "first\nsecond"])

    var output = String()
    table.write_csv_to(output)

    assert_equal(
        output,
        (
            '"Name, quoted",Note\r\n'
            '"a,b","said ""hello"""\r\n'
            'plain,"first\nsecond"\r\n'
        ),
    )


def test_custom_separator() raises:
    var table = _table([Column("A"), Column("B")])
    table.add_text_row(["x;y", "z"])

    var output = String()
    table.write_csv_to(output, separator=";")

    assert_equal(output, 'A;B\r\n"x;y";z\r\n')


def test_skips_presentation_only_rows() raises:
    var table = _table([Column("A")])
    table.title = "Ignored title"
    table.add_text_row(["first"])
    table.add_rule()
    table.add_blank()
    table.add_text_row(["second"])

    var output = String()
    table.write_csv_to(output)

    assert_equal(output, "A\r\nfirst\r\nsecond\r\n")


def test_writes_to_caller_owned_file() raises:
    var path = Path(gettempdir().value()) / "professor_test_table.csv"
    var table = _table([Column("A"), Column("B")])
    table.add_text_row(["x", "y"])

    with open(path, "w") as file:
        table.write_csv_to(file, separator=";")
    assert_equal(path.read_text(), "A;B\r\nx;y\r\n")
    remove(path)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
