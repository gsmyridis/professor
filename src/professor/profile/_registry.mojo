from std.reflection import SourceLocation
from std.collections import Dict
from std.hashlib import default_comp_time_hasher, Hasher
from std.os import abort

# ===----------------------------------------------------------------------=== #
# Call site key
# ===----------------------------------------------------------------------=== #


@always_inline
def _site_hash(name_hash: UInt64, loc: SourceLocation) -> UInt64:
    """Mixes the cheap numeric portion of a source location into a comptime
    name hash. The file name remains part of the equality check."""
    var h = (name_hash ^ UInt64(loc.line())) * 0x100000001B3
    return (h ^ UInt64(loc.column())) * 0x100000001B3


@fieldwise_init
struct _SiteKey(Copyable, Equatable, Hashable, Movable):
    """Complete site identity with a cheaply hashable fingerprint."""

    var fingerprint: UInt64
    var name: StaticString
    var file: StaticString
    var line: Int
    var column: Int

    @always_inline
    def __hash__(self, mut hasher: Some[Hasher]):
        hasher.update(self.fingerprint)

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        return (
            self.fingerprint == other.fingerprint
            and self.line == other.line
            and self.column == other.column
            and _same_static_string(self.name, other.name)
            and _same_static_string(self.file, other.file)
        )


# ===----------------------------------------------------------------------=== #
# Call site registry
# ===----------------------------------------------------------------------=== #


struct _Registry[Capacity: Int](Defaultable, Movable) where Capacity > 0:
    """ """

    comptime _SiteDictType = Dict[_SiteKey, Int, default_comp_time_hasher]

    var _next_index: Int
    """Index of the next available anchor."""

    var _inner: Self._SiteDictType
    """Map from call-site to anchor index."""

    def __init__(out self):
        self._next_index = Self.Capacity + 1
        self._inner = Self._SiteDictType(capacity=Self.Capacity)

    def get_index(mut self, site: _SiteKey) -> Int:
        try:
            return self._inner[site]
        except:
            var index = self._next_index
            self._inner[site.copy()] = index
            self._next_index += 1
            return index


# ===----------------------------------------------------------------------=== #
# Helpers
# ===----------------------------------------------------------------------=== #


@always_inline
def _same_static_string(lhs: StaticString, rhs: StaticString) -> Bool:
    return lhs.unsafe_ptr() == rhs.unsafe_ptr() or lhs == rhs


@always_inline
def _hash_comp_time(string: StaticString) -> UInt64:
    return hash[HasherType=default_comp_time_hasher](string)
