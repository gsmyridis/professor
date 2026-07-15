from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from parser import Parser, TokenKind, Tokenizer, ValueKind, parse_json


def test_tokenizer_peek_does_not_advance() raises:
    var tokenizer = Tokenizer("[true]")
    var peeked = tokenizer.peek_next()
    var consumed = tokenizer.next_token()
    assert_true(peeked.kind == TokenKind.OpenBracket)
    assert_true(consumed.kind == TokenKind.OpenBracket)


def test_scalar_values() raises:
    var null_value = parse_json("null")
    assert_true(null_value)
    assert_true(null_value.take().kind == ValueKind.Null)

    var bool_value = parse_json("false")
    assert_true(bool_value)
    var boolean = bool_value.take()
    assert_true(boolean.kind == ValueKind.Bool)
    assert_false(boolean.bool_value)

    var number_value = parse_json("-12.90e1")
    assert_true(number_value)
    var number = number_value.take()
    assert_true(number.kind == ValueKind.Number)
    assert_almost_equal(number.number_value, -129.0)

    var string_value = parse_json('"hello"')
    assert_true(string_value)
    var string = string_value.take()
    assert_true(string.kind == ValueKind.String)
    assert_equal(string.string_value, "hello")


def test_empty_input() raises:
    var parser = Parser("  \n")
    var parsed = parser.parse()
    assert_false(parsed)


def test_recursive_array_and_object() raises:
    var parsed = parse_json(
        """
        {
          "one": 1,
          "array": [true, false, null, {"nested": 2.5}]
        }
        """
    )
    assert_true(parsed)
    var root = parsed.take()
    assert_true(root.kind == ValueKind.Object)
    assert_equal(len(root.object_value), 2)

    ref one = root.object_value["one"][]
    assert_true(one.kind == ValueKind.Number)
    assert_almost_equal(one.number_value, 1.0)

    ref array = root.object_value["array"][]
    assert_true(array.kind == ValueKind.Array)
    assert_equal(len(array.array_value), 4)
    assert_true(array.array_value[0][].kind == ValueKind.Bool)
    assert_true(array.array_value[0][].bool_value)
    assert_true(array.array_value[2][].kind == ValueKind.Null)

    ref nested = array.array_value[3][]
    assert_true(nested.kind == ValueKind.Object)
    assert_almost_equal(nested.object_value["nested"][].as_number(), 2.5)


def test_rejects_invalid_structure() raises:
    with assert_raises(contains="trailing comma in JSON array"):
        _ = parse_json("[1, 2,]")
    with assert_raises(contains="missing colon"):
        _ = parse_json('{"one" 1}')
    with assert_raises(contains="duplicate JSON object key"):
        _ = parse_json('{"one": 1, "one": 2}')
    with assert_raises(contains="extra data"):
        _ = parse_json("true false")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
