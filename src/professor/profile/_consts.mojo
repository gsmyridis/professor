from std.sys import is_defined


def _profiling_is_enabled() -> Bool:
    return is_defined["PROFESSOR_PROFILE"]()


comptime UNCLAIMED_ANCHOR_LABEL: StaticString = ""
