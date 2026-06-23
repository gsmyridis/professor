from std.os import abort


def unimplemented() -> Never:
    abort("Unimplemented")


def todo() -> Never:
    abort("Todo")
