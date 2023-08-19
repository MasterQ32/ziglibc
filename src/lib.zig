const std = @import("std");
const modules = @import("modules");
comptime {
    if (modules.glibcstart) _ = @import("glibcstart.zig");
    if (modules.cstd) _ = @import("cstd.zig");
    if (modules.posix) _ = @import("posix.zig");
    if (modules.linux) _ = @import("linux.zig");
    if (modules.gnu) _ = @import("gnu.zig");
}

const builtin = @import("builtin");

pub const std_options = if (builtin.target.os.tag == .freestanding) struct {
    pub fn logFn(
        comptime message_level: std.log.Level,
        comptime scope: @TypeOf(.enum_literal),
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = args;
        _ = format;
        _ = scope;
        _ = message_level; //
    }
} else struct {};
