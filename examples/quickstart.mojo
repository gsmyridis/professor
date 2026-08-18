from professor import GlobalProfiler, WallClock


comptime Prof = GlobalProfiler[WallClock, Tag="quickstart"]


def main() raises:
    Prof.start()

    var checksum = 0
    for batch in range(20):
        with Prof.zone["pipeline"]():
            var values = List[Int]()

            with Prof.zone["prepare"]():
                for i in range(50_000):
                    values.append((i * 17 + batch) % 997)

            with Prof.zone["aggregate"]():
                for value in values:
                    checksum += value

    Prof.end()

    print("checksum:", checksum)
    print(Prof.report())
