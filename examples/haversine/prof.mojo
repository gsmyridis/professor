from professor import GlobalProfiler, WallClock

comptime Profiler = GlobalProfiler[WallClock, Tag="haversine"]

comptime HAVERSINE = 0
comptime PARSE = 1
comptime PARSE_VALUE = 2
comptime PARSE_INPUT = 3
comptime TOKENISER = 4
comptime STRING = 5
comptime PARSE_STRING = 6
comptime PARSE_NUMBER = 7
comptime COMPUTE = 8
