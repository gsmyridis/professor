from std.testing import TestSuite, assert_equal, assert_raises

from professor.os.linux.token import CounterToken
from professor.os.linux import Counts


def test_counts_are_addressable_by_token() raises:
    var cycles = CounterToken(unsafe_group_id=1, unsafe_event_id=10)
    var instructions = CounterToken(unsafe_group_id=1, unsafe_event_id=20)
    var tokens: List[CounterToken] = [cycles, instructions]
    var values: List[UInt64] = [120, 80]
    var counts = Counts(tokens^, values^, 100, 50)

    assert_equal(counts[cycles], 120)
    assert_equal(counts[instructions], 80)
    assert_equal(counts.count(cycles).time_enabled, 100)
    assert_equal(counts.count(cycles).time_running, 50)
    assert_equal(counts.scaled(instructions), 160.0)


def test_counts_reject_foreign_tokens() raises:
    var cycles = CounterToken(unsafe_group_id=1, unsafe_event_id=10)
    var foreign = CounterToken(unsafe_group_id=2, unsafe_event_id=10)
    var tokens: List[CounterToken] = [cycles]
    var values: List[UInt64] = [120]
    var counts = Counts(tokens^, values^, 100, 100)

    with assert_raises(contains="not present"):
        _ = counts[foreign]


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
