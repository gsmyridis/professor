trait Event:
    """A typed handle to a hardware performance counter event.

    `name()` is the key into the kpep database; all other event metadata is
    runtime information owned by `Database`.
    """

    def name(self) -> StaticString:
        ...
