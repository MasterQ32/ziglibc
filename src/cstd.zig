const builtin = @import("builtin");

pub usingnamespace if (builtin.target.os.tag != .freestanding)
    @import("cstd/hosted.zig")
else
    struct {};

pub usingnamespace @import("cstd/freestanding.zig");
