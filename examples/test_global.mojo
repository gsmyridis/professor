from professor.apple.kperf import kpc_get_counting
from std.ffi import _Global
from std.os import abort


def main() raises:
    print("first call:", kpc_get_counting())
    print("second call:", kpc_get_counting())
