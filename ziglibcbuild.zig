const std = @import("std");
const build = std.Build;
const CompileStep = build.Step.Compile;

pub const LinkKind = enum { static, shared };
pub const LibVariant = enum {
    only_std,
    only_posix,
    only_linux,
    only_gnu,
    full,
};
pub const Start = enum {
    none,
    ziglibc,
    glibc,
};

pub const Features = struct {
    pub const full = Features{
        .cstd = true,
        .linux = true,
        .posix = true,
        .gnu = true,
    };
    pub const only_std = Features{
        .cstd = true,
        .linux = false,
        .posix = false,
        .gnu = false,
    };
    pub const only_posix = Features{
        .cstd = false,
        .linux = false,
        .posix = true,
        .gnu = false,
    };
    pub const only_linux = Features{
        .cstd = false,
        .linux = true,
        .posix = false,
        .gnu = false,
    };
    pub const only_gnu = Features{
        .cstd = false,
        .linux = false,
        .posix = false,
        .gnu = true,
    };

    cstd: bool,
    linux: bool,
    posix: bool,
    gnu: bool,

    pub fn isFull(ft: Features) bool {
        return ft.cstd and ft.linux and ft.posix and ft.gnu;
    }
};
pub const ZigLibcOptions = struct {
    features: Features,

    name: ?[]const u8 = null,
    link: LinkKind,
    start: Start,
    trace: bool,
    target: std.zig.CrossTarget,
    optimize: std.builtin.Mode,
};

fn relpath(comptime src_path: []const u8) std.Build.LazyPath {
    if (comptime std.fs.path.dirname(@src().file)) |dir|
        return .{ .path = dir ++ std.fs.path.sep_str ++ src_path };
    return .{ .path = src_path };
}

/// Provides a _start symbol that will call C main
pub fn addZigStart(
    builder: *build,
    target: std.zig.CrossTarget,
    optimize: anytype,
) *CompileStep {
    const lib = builder.addStaticLibrary(.{
        .name = "start",
        .root_source_file = relpath("src/start.zig"),
        .target = target,
        .optimize = optimize,
    });
    // TODO: not sure if this is reallly needed or not, but it shouldn't hurt
    //       anything except performance to enable it
    lib.force_pic = true;
    return lib;
}

// Returns ziglibc as a CompileStep
// Caller will also need to add the include path to get the C headers
pub fn addLibc(builder: *std.build.Builder, opt: ZigLibcOptions) *CompileStep {
    const name = if (opt.name) |name|
        name
    else blk: {
        var name_builder = std.ArrayList(u8).init(builder.allocator);
        defer name_builder.deinit();

        name_builder.appendSlice("cguana") catch @panic("oom");

        if (!opt.features.isFull()) {
            if (!opt.features.cstd) name_builder.appendSlice("-nostd") catch @panic("oom");
            if (opt.features.posix) name_builder.appendSlice("-posix") catch @panic("oom");
            if (opt.features.linux) name_builder.appendSlice("-linux") catch @panic("oom");
            if (opt.features.gnu) name_builder.appendSlice("-gnu") catch @panic("oom");
        }

        break :blk name_builder.toOwnedSlice() catch @panic("oom");
    };

    const trace_options = builder.addOptions();
    trace_options.addOption(bool, "enabled", opt.trace);

    const modules_options = builder.addOptions();
    modules_options.addOption(bool, "glibcstart", switch (opt.start) {
        .glibc => true,
        else => false,
    });
    const index = relpath("src/lib.zig");
    const lib = switch (opt.link) {
        .static => builder.addStaticLibrary(.{
            .name = name,
            .root_source_file = index,
            .target = opt.target,
            .optimize = opt.optimize,
        }),
        .shared => builder.addSharedLibrary(.{
            .name = name,
            .root_source_file = index,
            .target = opt.target,
            .optimize = opt.optimize,
            .version = if (opt.features.isFull())
                .{ .major = 6, .minor = 0, .patch = 0 }
            else
                null,
        }),
    };
    // TODO: not sure if this is reallly needed or not, but it shouldn't hurt
    //       anything except performance to enable it
    lib.force_pic = true;
    lib.addOptions("modules", modules_options);
    lib.addOptions("trace_options", trace_options);
    const c_flags = [_][]const u8{
        "-std=c11",
    };
    modules_options.addOption(bool, "cstd", opt.features.cstd);
    if (opt.features.cstd) {
        lib.addCSourceFile(.{ .file = relpath("src/printf.c"), .flags = &c_flags });
        lib.addCSourceFile(.{ .file = relpath("src/scanf.c"), .flags = &c_flags });
        if (opt.target.getOsTag() == .linux) {
            lib.addAssemblyFile(relpath("src/linux/jmp.s"));
        }
    }
    modules_options.addOption(bool, "posix", opt.features.posix);
    if (opt.features.posix) {
        lib.addCSourceFile(.{ .file = relpath("src/posix.c"), .flags = &c_flags });
    }

    modules_options.addOption(bool, "linux", opt.features.linux);
    if (opt.features.cstd or opt.features.posix) {
        lib.addIncludePath(relpath("inc/libc"));
        lib.addIncludePath(relpath("inc/posix"));
    }

    modules_options.addOption(bool, "gnu", opt.features.gnu);
    if (opt.features.gnu) {
        lib.addIncludePath(relpath("inc/gnu"));
    }
    return lib;
}
