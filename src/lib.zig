const modules = @import("modules");
comptime {
    if (modules.glibcstart) _ = @import("glibcstart.zig");
    if (modules.cstd) _ = @import("cstd.zig");
    if (modules.posix) _ = @import("posix.zig");
    if (modules.linux) _ = @import("linux.zig");
    if (modules.gnu) _ = @import("gnu.zig");
}

const std = @import("std");
pub fn log(level: std.log.Level, comptime scope: @TypeOf(.literal), comptime fmt: []const u8, args: anytype) void {
    _ = scope;
    _ = level;
    _ = fmt;
    _ = args;
}
