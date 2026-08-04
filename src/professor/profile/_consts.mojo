from std.sys import is_defined


def is_profiling_enabled() -> Bool:
    return is_defined["PROFESSOR_PROFILE"]()


comptime UNCLAIMED_ANCHOR_LABEL: StaticString = ""
