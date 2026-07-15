from std.math import asin, cos, pi, sin, sqrt
from std.pathlib import Path
from std.sys import argv

from professor.measure.default import WallClock

from parser import (
    HaversineProfiler,
    Value,
    ValueKind,
    parse_json_profiled,
)


def degrees_to_radians(angle: Float64) -> Float64:
    return angle * pi / 180.0


def calculate_haversine_distance(
    radius: Float64,
    phi_0_degrees: Float64,
    theta_0_degrees: Float64,
    phi_1_degrees: Float64,
    theta_1_degrees: Float64,
) -> Float64:
    var zone = HaversineProfiler.zone["haversine"]()
    var phi_0 = degrees_to_radians(phi_0_degrees)
    var phi_1 = degrees_to_radians(phi_1_degrees)
    var theta_0 = degrees_to_radians(theta_0_degrees)
    var theta_1 = degrees_to_radians(theta_1_degrees)

    var delta_theta = theta_1 - theta_0
    var delta_phi = phi_1 - phi_0
    var sin_theta = sin(delta_theta / 2.0)
    var sin_phi = sin(delta_phi / 2.0)
    var root_term = (
        sin_theta * sin_theta + cos(theta_0) * cos(theta_1) * sin_phi * sin_phi
    )
    var result = 2.0 * radius * asin(sqrt(root_term))
    zone^.close()
    return result


def number_member(object: Value, key: String) raises -> Float64:
    if object.kind != ValueKind.Object:
        raise Error("expected a JSON object while reading ", key)
    if key not in object.object_value:
        raise Error("missing JSON number: ", key)
    return object.object_value[key][].as_number()


def _compute_average(pairs: Value, radius: Float64) raises -> Float64:
    var sum = 0.0
    for i in range(len(pairs.array_value)):
        ref pair = pairs.array_value[i][]
        sum += calculate_haversine_distance(
            radius,
            number_member(pair, "x0"),
            number_member(pair, "y0"),
            number_member(pair, "x1"),
            number_member(pair, "y1"),
        )
    if len(pairs.array_value) == 0:
        raise Error("pairs array is empty")
    return sum / Float64(len(pairs.array_value))


def compute_average(pairs: Value, radius: Float64) raises -> Float64:
    var zone = HaversineProfiler.zone["compute"]()
    var result: Float64
    try:
        result = _compute_average(pairs, radius)
    except error:
        zone^.close()
        raise error^
    zone^.close()
    return result


def main() raises:
    var args = argv()
    if len(args) != 2:
        print(
            "Usage: mojo run -I src -I examples/haversine/parser "
            "examples/haversine/parser/main.mojo <pairs.json>"
        )
        return

    var input = Path(args[1]).read_text()
    var parsed = parse_json_profiled(input)
    if not parsed:
        raise Error("pairs file is empty")
    var root = parsed.take()
    if root.kind != ValueKind.Object:
        raise Error("pairs file root must be a JSON object")

    var average_distance = number_member(root, "avg_dist")
    var radius = number_member(root, "radius")
    if "pairs" not in root.object_value:
        raise Error("missing JSON array: pairs")
    ref pairs = root.object_value["pairs"][]
    if pairs.kind != ValueKind.Array:
        raise Error("JSON member 'pairs' must be an array")

    var computed_average = compute_average(pairs, radius)

    print("Number of pairs:", len(pairs.array_value))
    print("Radius:", radius)
    print(
        "Difference between read and computed value:",
        average_distance - computed_average,
    )
    print("\nProfile:")
    print(HaversineProfiler.report())
