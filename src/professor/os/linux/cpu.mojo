@fieldwise_init
struct CpuId(ImplicitlyCopyable, RegisterPassable, Writable):

    var id: UInt32

    comptime Any = Self(-1)
