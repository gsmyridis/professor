import argparse
import json
import time

import numpy as np
from numpy.typing import NDArray

PHI_MIN_DEGREES, PHI_MAX_DEGREES = -180, 180
THETA_MIN_DEGREES, THETA_MAX_DEGREES = -90, 90


def generate_cluster(
    n_pairs: int,
    phi: np.float64,
    theta: float,
    dphi: float,
    dtheta: float,
) -> tuple[NDArray[np.float64], NDArray[np.float64]]:
    """
    Generates a cluster of random pairs of points.

    All the points in the claster are around a central point (`phi`, `theta`),
    and can deviate from it `dphi` and `dtheta` aat the most.

    Parameters:
    -----------

    `n_points`: Number of pairs in the cluster.
    `phi`: Longitude of the central point of the cluster.
    `theta`: Latitude of the central point of the cluster.
    `dphi`: Maximum longitudinal diviation of the points.
    `dtheta`: Maximum latitudinal diviation of the points.

    Returns:
    --------

    The longitudes and latitudes for the points of each pair.
    """
    phis = phi + np.random.uniform(-dphi, dphi, (n_pairs, 2))
    phis = np.clip(phis, PHI_MIN_DEGREES, PHI_MAX_DEGREES).astype(float)

    thetas = theta + np.random.uniform(-dtheta, dtheta, (n_pairs, 2))
    thetas = np.clip(thetas, THETA_MIN_DEGREES, THETA_MAX_DEGREES).astype(float)

    return phis, thetas


def generate_pairs(
    n_pairs: int, n_clusters: int
) -> tuple[NDArray[np.float64], NDArray[np.float64]]:
    """
    It generates `n_pairs` random pairs of points on the sphere with
    specified radius.

    The random points are sampled grouped in `n_clusters` clusters with
    centers chosen randomly.

    Parameters:
    -----------

    `n_pairs`: Number of random pairs of points.
    `n_clusters`: Number of clusters to sample in.

    Returns:
    --------

    Randomly generated pairs of points.
    """
    phis_center = np.random.uniform(PHI_MIN_DEGREES, PHI_MAX_DEGREES, n_clusters)
    thetas_center = np.random.uniform(THETA_MIN_DEGREES, THETA_MAX_DEGREES, n_clusters)

    n_pairs_per_cluster = np.diff(
        np.floor(np.linspace(0, n_pairs, n_clusters + 1))
    ).astype(int)
    dphi = (PHI_MAX_DEGREES - PHI_MIN_DEGREES) / n_clusters
    dtheta = (THETA_MAX_DEGREES - THETA_MIN_DEGREES) / n_clusters
    n_clusters = 2 if n_clusters == 1 else n_clusters

    assert len(phis_center) == len(thetas_center)
    assert len(n_pairs_per_cluster) == len(phis_center)

    phis_all: list[NDArray[np.float64]] = []
    thetas_all: list[NDArray[np.float64]] = []
    for i in range(n_clusters):
        phis, thetas = generate_cluster(
            n_pairs=n_pairs_per_cluster[i],
            phi=phis_center[i],
            theta=thetas_center[i],
            dphi=dphi,
            dtheta=dtheta,
        )

        phis_all.append(phis)
        thetas_all.append(thetas)

    return np.vstack(phis_all), np.vstack(thetas_all)


def haversine_distance(
    phis0: NDArray[np.float64],
    thetas0: NDArray[np.float64],
    phis1: NDArray[np.float64],
    thetas1: NDArray[np.float64],
    radius: float,
) -> NDArray[np.float64]:
    """
    Calculates the haversine distances between all points given their
    latitude and longitude in degrees, and the radius of the sphere.

    Parameters:
    -----------

    `phis0`: Longitudes of first points in the pairs.
    `thetas0`: Lattitudes of first points in the pairs.
    `phis1`: Longitudes of second points in the pairs.
    `thetas1`: Lattitudes of second points in the pairs.
    `radius`: The radius of the sphere.

    Returns:
    --------

    The haversine distances of all pairs in the same units as the radius.
    """

    dphis, thetas0, thetas1 = map(np.radians, [phis0 - phis1, thetas0, thetas1])
    dthetas = thetas1 - thetas0

    root_term_0 = np.sin(dthetas / 2) ** 2
    root_term_1 = np.cos(thetas0) * np.cos(thetas1) * np.sin(dphis / 2) ** 2

    return 2 * radius * np.asin(np.sqrt(root_term_0 + root_term_1))


def generate(pairs: int, radius: float, clusters: int, output: str):
    """
    Generates the random pairs of points on the sphere, calculates the
    average distance between the points in the pair and save the results
    in a json file.
    """
    start_time = time.time()

    # Prin
    print("Pairs:", pairs)
    print("Radius:", radius)
    print("Clusters:", clusters)
    print("Output:", output)

    # Generate random pairs of points.
    phis, thetas = generate_pairs(n_pairs=pairs, n_clusters=clusters)

    gen_end_time = time.time()

    distances = haversine_distance(
        phis0=phis[:, 0],
        thetas0=thetas[:, 0],
        phis1=phis[:, 1],
        thetas1=thetas[:, 1],
        radius=radius,
    )
    avg_dist = np.average(distances)

    end_time = time.time()

    # Print results and performance
    print("Result:", str(avg_dist))
    print("Generate:" + str(gen_end_time - start_time), "seconds")
    print("Math:", str(end_time - gen_end_time), "seconds")
    print("Total:", str(end_time - start_time), "seconds")
    print(
        "Throughput:",
        str(pairs / (end_time - start_time)),
        "haversines/second",
    )

    # Format and save the result in JSON file.
    result = {
        "pairs": [
            {
                "x0": xs[0],
                "y0": ys[0],
                "x1": xs[1],
                "y1": ys[1],
            }
            for xs, ys in zip(phis, thetas)
        ],
        "avg_dist": avg_dist,
        "radius": radius,
    }
    with open(output, "w") as file:
        json.dump(result, file, indent=2)
        print("Saved result in:", output)


def calculate(path: str):
    """
    Calculates the Haversine distances for all the points read from
    a JSON input files.
    """

    start_time = time.time()
    with open(path, "br") as file:
        in_file = json.load(file)

    n_pairs = len(in_file["pairs"])
    phis_0, phis_1 = np.zeros(n_pairs), np.zeros(n_pairs)
    thetas_0, thetas_1 = np.zeros(n_pairs), np.zeros(n_pairs)

    for i in range(n_pairs):
        phis_0[i] = in_file["pairs"][i]["x0"]
        phis_1[i] = in_file["pairs"][i]["x1"]
        thetas_0[i] = in_file["pairs"][i]["y0"]
        thetas_1[i] = in_file["pairs"][i]["y1"]

    load_end_time = time.time()

    distances = haversine_distance(
        phis0=phis_0,
        thetas0=thetas_0,
        phis1=phis_1,
        thetas1=thetas_1,
        radius=in_file["radius"],
    )
    avg_dist = np.average(distances)
    end_time = time.time()

    print("Read average distance:", in_file["avg_dist"])
    print("Computed average distance:", avg_dist)
    print("Parsing time:", load_end_time - start_time)
    print("Computing time:", end_time - load_end_time)


def cli():
    parser = argparse.ArgumentParser(
        description="Generate and calculate haversine coordinate pairs."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    generate_parser = commands.add_parser(
        "generate", help="Generate random coordinate pairs."
    )
    generate_parser.add_argument("pairs", type=int, help="Number of pairs")
    generate_parser.add_argument("--radius", type=float, default=1.0)
    generate_parser.add_argument("--clusters", type=int, default=1)
    generate_parser.add_argument("--output", default="pairs.json")

    calculate_parser = commands.add_parser(
        "calculate", help="Calculate distances from a generated JSON file."
    )
    calculate_parser.add_argument("path", help="Path to the JSON input")

    args = parser.parse_args()
    if args.command == "generate":
        generate(args.pairs, args.radius, args.clusters, args.output)
    else:
        calculate(args.path)


if __name__ == "__main__":
    cli()
