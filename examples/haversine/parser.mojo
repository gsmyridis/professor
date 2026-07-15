"""A direct Mojo port of the example's Rust JSON parser structure.

Mojo requires an indirection for recursive values, so arrays and objects own
their child `Value`s through `OwnedPointer`. Apart from that ownership detail,
the implementation follows the Rust `Token` -> `Tokenizer` -> `Value` ->
`Parser` organization.
"""

from std.memory import OwnedPointer

from professor.measure.default import WallClock
from professor.profile import Profiler


comptime HaversineProfiler = Profiler[
    WallClock, Tag="haversine.parser", Capacity=5
]


@fieldwise_init
struct TokenKind(Equatable, ImplicitlyCopyable):
    var _value: UInt8

    comptime Eof = Self(0)
    comptime OpenBrace = Self(1)
    comptime CloseBrace = Self(2)
    comptime OpenBracket = Self(3)
    comptime CloseBracket = Self(4)
    comptime Comma = Self(5)
    comptime Colon = Self(6)
    comptime Null = Self(7)
    comptime Bool = Self(8)
    comptime String = Self(9)
    comptime Number = Self(10)


struct Token(Movable):
    var kind: TokenKind
    var bool_value: Bool
    var string_value: String
    var number_value: Float64

    def __init__(out self, kind: TokenKind):
        self.kind = kind
        self.bool_value = False
        self.string_value = String()
        self.number_value = 0.0

    @staticmethod
    def boolean(value: Bool) -> Self:
        var token = Self(TokenKind.Bool)
        token.bool_value = value
        return token^

    @staticmethod
    def string(var value: String) -> Self:
        var token = Self(TokenKind.String)
        token.string_value = value^
        return token^

    @staticmethod
    def number(value: Float64) -> Self:
        var token = Self(TokenKind.Number)
        token.number_value = value
        return token^


def _is_digit(byte: Byte) -> Bool:
    return Byte(ord("0")) <= byte <= Byte(ord("9"))


def _is_number_delimiter(byte: Byte) -> Bool:
    return (
        byte == Byte(ord(" "))
        or byte == Byte(ord("\t"))
        or byte == Byte(ord("\n"))
        or byte == Byte(ord("\r"))
        or byte == Byte(ord(","))
        or byte == Byte(ord("]"))
        or byte == Byte(ord("}"))
    )


struct Tokenizer:
    var _input: List[Byte]
    var _cursor: Int

    def __init__(out self, input: StringSlice):
        self._input = List(input.as_bytes())
        self._cursor = 0

    def next_token(mut self) raises -> Token:
        self._eat_whitespace()
        if self._cursor == len(self._input):
            return Token(TokenKind.Eof)

        var byte = self._input[self._cursor]
        self._cursor += 1

        if byte == Byte(ord("[")):
            return Token(TokenKind.OpenBracket)
        if byte == Byte(ord("]")):
            return Token(TokenKind.CloseBracket)
        if byte == Byte(ord("{")):
            return Token(TokenKind.OpenBrace)
        if byte == Byte(ord("}")):
            return Token(TokenKind.CloseBrace)
        if byte == Byte(ord(",")):
            return Token(TokenKind.Comma)
        if byte == Byte(ord(":")):
            return Token(TokenKind.Colon)
        if byte == Byte(ord("n")):
            self._expect_remainder("ull")
            return Token(TokenKind.Null)
        if byte == Byte(ord("t")):
            self._expect_remainder("rue")
            return Token.boolean(True)
        if byte == Byte(ord("f")):
            self._expect_remainder("alse")
            return Token.boolean(False)
        if byte == Byte(ord('"')):
            return Token.string(self._next_string())
        if byte == Byte(ord("-")) or _is_digit(byte):
            return Token.number(self._next_number(self._cursor - 1))

        raise Error("unexpected character at byte ", self._cursor - 1)

    def peek_next(mut self) raises -> Token:
        var saved_cursor = self._cursor
        try:
            var token = self.next_token()
            self._cursor = saved_cursor
            return token^
        except error:
            self._cursor = saved_cursor
            raise error^

    def _expect_remainder(mut self, expected: StringSlice) raises:
        var expected_bytes = expected.as_bytes()
        if self._cursor + len(expected_bytes) > len(self._input):
            raise Error("reached EOF while reading JSON literal")
        for i in range(len(expected_bytes)):
            if self._input[self._cursor + i] != expected_bytes[i]:
                raise Error("invalid JSON literal at byte ", self._cursor)
        self._cursor += len(expected_bytes)

    def _next_string(mut self) raises -> String:
        var start = self._cursor
        while self._cursor < len(self._input):
            var byte = self._input[self._cursor]
            if byte == Byte(ord('"')):
                var value = String(
                    unsafe_from_utf8=Span(self._input)[start : self._cursor]
                )
                self._cursor += 1
                return value^
            if byte == Byte(ord("\\")):
                raise Error("escaped strings are not supported in this example")
            if byte < Byte(0x20):
                raise Error("control character in JSON string")
            self._cursor += 1
        raise Error("reached EOF while reading JSON string")

    def _next_number(mut self, start: Int) raises -> Float64:
        self._cursor = start

        if self._consume(Byte(ord("-"))):
            pass

        if self._consume(Byte(ord("0"))):
            if self._cursor < len(self._input) and _is_digit(
                self._input[self._cursor]
            ):
                raise Error("leading zero in JSON number")
        else:
            if self._cursor >= len(self._input) or not (
                Byte(ord("1")) <= self._input[self._cursor] <= Byte(ord("9"))
            ):
                raise Error("invalid JSON number")
            self._cursor += 1
            while self._cursor < len(self._input) and _is_digit(
                self._input[self._cursor]
            ):
                self._cursor += 1

        if self._consume(Byte(ord("."))):
            if self._cursor >= len(self._input) or not _is_digit(
                self._input[self._cursor]
            ):
                raise Error("expected digit after decimal point")
            while self._cursor < len(self._input) and _is_digit(
                self._input[self._cursor]
            ):
                self._cursor += 1

        if self._consume(Byte(ord("e"))) or self._consume(Byte(ord("E"))):
            if not self._consume(Byte(ord("+"))):
                _ = self._consume(Byte(ord("-")))
            if self._cursor >= len(self._input) or not _is_digit(
                self._input[self._cursor]
            ):
                raise Error("expected exponent digits")
            while self._cursor < len(self._input) and _is_digit(
                self._input[self._cursor]
            ):
                self._cursor += 1

        if self._cursor < len(self._input) and not _is_number_delimiter(
            self._input[self._cursor]
        ):
            raise Error("invalid character in JSON number")

        var number = String(
            unsafe_from_utf8=Span(self._input)[start : self._cursor]
        )
        return atof(number)

    def _eat_whitespace(mut self):
        while self._cursor < len(self._input):
            var byte = self._input[self._cursor]
            if not (
                byte == Byte(ord(" "))
                or byte == Byte(ord("\t"))
                or byte == Byte(ord("\n"))
                or byte == Byte(ord("\r"))
            ):
                return
            self._cursor += 1

    def _consume(mut self, expected: Byte) -> Bool:
        if (
            self._cursor < len(self._input)
            and self._input[self._cursor] == expected
        ):
            self._cursor += 1
            return True
        return False


@fieldwise_init
struct ValueKind(Equatable, ImplicitlyCopyable):
    var _value: UInt8

    comptime Null = Self(0)
    comptime Bool = Self(1)
    comptime Number = Self(2)
    comptime String = Self(3)
    comptime Array = Self(4)
    comptime Object = Self(5)


struct Value(Movable):
    var kind: ValueKind
    var bool_value: Bool
    var number_value: Float64
    var string_value: String
    var array_value: List[OwnedPointer[Value]]
    var object_value: Dict[String, OwnedPointer[Value]]

    def __init__(out self, kind: ValueKind):
        self.kind = kind
        self.bool_value = False
        self.number_value = 0.0
        self.string_value = String()
        self.array_value = List[OwnedPointer[Value]]()
        self.object_value = Dict[String, OwnedPointer[Value]]()

    @staticmethod
    def null() -> Self:
        return Self(ValueKind.Null)

    @staticmethod
    def boolean(value: Bool) -> Self:
        var result = Self(ValueKind.Bool)
        result.bool_value = value
        return result^

    @staticmethod
    def number(value: Float64) -> Self:
        var result = Self(ValueKind.Number)
        result.number_value = value
        return result^

    @staticmethod
    def string(var value: String) -> Self:
        var result = Self(ValueKind.String)
        result.string_value = value^
        return result^

    @staticmethod
    def array(var value: List[OwnedPointer[Value]]) -> Self:
        var result = Self(ValueKind.Array)
        result.array_value = value^
        return result^

    @staticmethod
    def object(var value: Dict[String, OwnedPointer[Value]]) -> Self:
        var result = Self(ValueKind.Object)
        result.object_value = value^
        return result^

    def as_number(self) raises -> Float64:
        if self.kind != ValueKind.Number:
            raise Error("JSON value is not a number")
        return self.number_value


struct Parser[profile: Bool = False]:
    var tokenizer: Tokenizer

    def __init__(out self, input: StringSlice):
        self.tokenizer = Tokenizer(input)

    def parse(mut self) raises -> Optional[Value]:
        comptime if Self.profile:
            return self._parse_profiled()
        else:
            return self._parse()

    def _parse_profiled(mut self) raises -> Optional[Value]:
        var zone = HaversineProfiler.zone["parse", 2]()
        var result: Optional[Value]
        try:
            result = self._parse()
        except error:
            zone^.close()
            raise error^
        zone^.close()
        return result^

    def _parse(mut self) raises -> Optional[Value]:
        var parsed = self.parse_value()
        var trailing = self.tokenizer.next_token()
        if trailing.kind != TokenKind.Eof:
            raise Error("extra data after JSON value")
        return parsed^

    def parse_value(mut self) raises -> Optional[Value]:
        comptime if Self.profile:
            return self._parse_value_profiled()
        else:
            return self._parse_value()

    def _parse_value_profiled(mut self) raises -> Optional[Value]:
        var zone = HaversineProfiler.zone["parse_value", 3]()
        var result: Optional[Value]
        try:
            result = self._parse_value()
        except error:
            zone^.close()
            raise error^
        zone^.close()
        return result^

    def _parse_value(mut self) raises -> Optional[Value]:
        var token = self.tokenizer.next_token()
        if token.kind == TokenKind.Eof:
            return None
        if token.kind == TokenKind.Null:
            return Value.null()
        if token.kind == TokenKind.Bool:
            return Value.boolean(token.bool_value)
        if token.kind == TokenKind.Number:
            return Value.number(token.number_value)
        if token.kind == TokenKind.String:
            return Value.string(token.string_value.copy())
        if token.kind == TokenKind.OpenBracket:
            return self._parse_array()
        if token.kind == TokenKind.OpenBrace:
            return self._parse_object()
        raise Error("invalid token at start of JSON value")

    def _parse_array(mut self) raises -> Value:
        var items = List[OwnedPointer[Value]]()
        var next = self.tokenizer.peek_next()
        if next.kind == TokenKind.CloseBracket:
            _ = self.tokenizer.next_token()
            return Value.array(items^)
        if next.kind == TokenKind.Eof:
            raise Error("reached EOF while parsing JSON array")

        while True:
            var maybe_value = self.parse_value()
            if not maybe_value:
                raise Error("reached EOF while parsing JSON array")
            var value = maybe_value.take()
            items.append(OwnedPointer(value^))

            var separator = self.tokenizer.next_token()
            if separator.kind == TokenKind.CloseBracket:
                return Value.array(items^)
            if separator.kind == TokenKind.Eof:
                raise Error("reached EOF while parsing JSON array")
            if separator.kind != TokenKind.Comma:
                raise Error(
                    "expected comma or closing bracket after array value"
                )

            var after_comma = self.tokenizer.peek_next()
            if after_comma.kind == TokenKind.CloseBracket:
                raise Error("trailing comma in JSON array")
            if after_comma.kind == TokenKind.Eof:
                raise Error("reached EOF while parsing JSON array")

    def _parse_object(mut self) raises -> Value:
        var members = Dict[String, OwnedPointer[Value]]()
        var next = self.tokenizer.peek_next()
        if next.kind == TokenKind.CloseBrace:
            _ = self.tokenizer.next_token()
            return Value.object(members^)
        if next.kind == TokenKind.Eof:
            raise Error("reached EOF while parsing JSON object")

        while True:
            var key_token = self.tokenizer.next_token()
            if key_token.kind == TokenKind.Eof:
                raise Error("reached EOF while parsing JSON object")
            if key_token.kind != TokenKind.String:
                raise Error("JSON object key is not a string")
            var key = key_token.string_value.copy()

            var colon = self.tokenizer.next_token()
            if colon.kind == TokenKind.Eof:
                raise Error("reached EOF while parsing JSON object")
            if colon.kind != TokenKind.Colon:
                raise Error("missing colon after JSON object key")

            var maybe_value = self.parse_value()
            if not maybe_value:
                raise Error("reached EOF while parsing JSON object")
            var value = maybe_value.take()

            if key in members:
                raise Error("duplicate JSON object key: ", key)
            members[key] = OwnedPointer(value^)

            var separator = self.tokenizer.next_token()
            if separator.kind == TokenKind.CloseBrace:
                return Value.object(members^)
            if separator.kind == TokenKind.Eof:
                raise Error("reached EOF while parsing JSON object")
            if separator.kind != TokenKind.Comma:
                raise Error(
                    "expected comma or closing brace after object value"
                )

            var after_comma = self.tokenizer.peek_next()
            if after_comma.kind == TokenKind.CloseBrace:
                raise Error("trailing comma in JSON object")
            if after_comma.kind == TokenKind.Eof:
                raise Error("reached EOF while parsing JSON object")


def parse_json(input: StringSlice) raises -> Optional[Value]:
    var parser = Parser(input)
    return parser.parse()


def parse_json_profiled(input: StringSlice) raises -> Optional[Value]:
    """Parses JSON with `parse` and every `parse_value` call profiled."""
    var parser = Parser[profile=True](input)
    return parser.parse()
