from std.builtin.rebind import downcast
from std.reflection import reflect


# ===-----------------------------------------------------------------------===
# Instrument
# ===-----------------------------------------------------------------------===


trait Instrument(Defaultable, ImplicitlyDeletable, Movable):
    """Produces supported metric samples on demand."""

    comptime MetricType: _MetricInner
    """Type of the sampled metric."""

    def measure(mut self) -> Self.MetricType:
        """Samples the associated metric."""
        ...


# ===-----------------------------------------------------------------------===
# Metric Type (MType)
# ===-----------------------------------------------------------------------===


@fieldwise_init
struct MType(Equatable, ImplicitlyCopyable):
    """Closed scalar quantity families understood by Professor."""

    var code: Int

    comptime Time = Self(0)
    comptime Count = Self(1)
    comptime DataSize = Self(2)


# ===-----------------------------------------------------------------------===
# Metric
# ===-----------------------------------------------------------------------===


trait Metric(_MetricInner):
    """A flat composite whose immediate fields are supported scalar metrics.

    Professor derives zero construction, fieldwise measurement operations, and
    report decomposition. A user-defined composite only declares its fields.
    """

    def __init__(out self):
        comptime r = reflect[Self]
        comptime types = r.field_types()
        comptime assert (
            r.field_count() > 0
        ), "a composite Metric must contain at least one scalar field"
        comptime for i in range(r.field_count()):
            comptime FieldType = types[i]
            comptime assert conforms_to(FieldType, _ScalarMetric), (
                "every field of a composite Metric must be a supported "
                "scalar metric; nested and opaque metrics are not allowed"
            )
            r.field_ref[i](self) = FieldType()

    def sub(self, other: Self) -> Self:
        """Subtracts `other` fieldwise. Wraps when `other` is the larger."""
        comptime r = reflect[Self]
        comptime types = r.field_types()
        var result = Self()
        comptime for i in range(r.field_count()):
            comptime FieldType = types[i]
            ref lhs = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](self)
            )
            ref rhs = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](other)
            )
            r.field_ref[i](result) = lhs.sub(rhs)
        return result^

    def add(self, other: Self) -> Self:
        """Adds `other` fieldwise."""
        comptime r = reflect[Self]
        comptime types = r.field_types()
        var result = Self()
        comptime for i in range(r.field_count()):
            comptime FieldType = types[i]
            ref lhs = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](self)
            )
            ref rhs = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](other)
            )
            r.field_ref[i](result) = lhs.add(rhs)
        return result^

    def div(self, count: UInt64) -> Self:
        """Divides every field by `count`, truncating toward zero."""
        comptime r = reflect[Self]
        comptime types = r.field_types()
        var result = Self()
        comptime for i in range(r.field_count()):
            comptime FieldType = types[i]
            ref field = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](self)
            )
            r.field_ref[i](result) = field.div(count)
        return result^

    def min(self, other: Self) -> Self:
        """Takes the fieldwise minimum, which need not be either operand."""
        comptime r = reflect[Self]
        comptime types = r.field_types()
        var result = Self()
        comptime for i in range(r.field_count()):
            comptime FieldType = types[i]
            ref lhs = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](self)
            )
            ref rhs = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](other)
            )
            r.field_ref[i](result) = lhs.min(rhs)
        return result^

    def max(self, other: Self) -> Self:
        """Takes the fieldwise maximum, which need not be either operand."""
        comptime r = reflect[Self]
        comptime types = r.field_types()
        var result = Self()
        comptime for i in range(r.field_count()):
            comptime FieldType = types[i]
            ref lhs = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](self)
            )
            ref rhs = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](other)
            )
            r.field_ref[i](result) = lhs.max(rhs)
        return result^

    def components(self) -> List[MetricComponent]:
        comptime r = reflect[Self]
        comptime names = r.field_names()
        comptime types = r.field_types()
        var result = List[MetricComponent](capacity=r.field_count())
        comptime for i in range(r.field_count()):
            comptime FieldType = types[i]
            ref field = rebind[downcast[FieldType, _ScalarMetric]](
                r.field_ref[i](self)
            )
            result.append(field._component(String(names[i])))
        return result^


trait _MetricInner(Copyable, Defaultable, ImplicitlyDeletable):
    """Internal operations shared by supported scalar and composite metrics."""

    def sub(self, other: Self) -> Self:
        """Subtracts `other` fieldwise. Wraps when `other` is the larger."""
        ...

    def add(self, other: Self) -> Self:
        """Adds `other` fieldwise."""
        ...

    def div(self, count: UInt64) -> Self:
        """Divides every field by `count`, truncating toward zero."""
        ...

    def min(self, other: Self) -> Self:
        """Takes the fieldwise minimum, which need not be either operand."""
        ...

    def max(self, other: Self) -> Self:
        """Takes the fieldwise maximum, which need not be either operand."""
        ...

    def components(self) -> List[MetricComponent]:
        """Decomposes into one scalar component per reported column."""
        ...


trait _ScalarMetric(_MetricInner):
    """Internal interface implemented only by supported scalar quantities."""

    def _component(self, var name: String) -> MetricComponent:
        ...

    def components(self) -> List[MetricComponent]:
        return [self._component(String())]


def _metric_any_less[M: _MetricInner](best: M, candidate: M) -> Bool:
    var best_components = best.components()
    var candidate_components = candidate.components()
    for i in range(len(best_components)):
        if candidate_components[i].value < best_components[i].value:
            return True
    return False


# ===-----------------------------------------------------------------------===
# Scalar metric component
# ===-----------------------------------------------------------------------===


struct MetricComponent(Copyable):
    """One scalar metric materialized for report construction."""

    var name: String
    var count_kind: String
    var kind: MType
    var value: UInt64
    var storage_scale: UInt64

    def __init__(
        out self,
        var name: String,
        var count_kind: String,
        kind: MType,
        value: UInt64,
        storage_scale: UInt64,
    ):
        self.name = name^
        self.count_kind = count_kind^
        self.kind = kind
        self.value = value
        self.storage_scale = storage_scale

    def canonical_value(self) -> Float64:
        return Float64(self.value) * Float64(self.storage_scale)
