const std = @import("std");
const libcbuild = @import("ziglibcbuild.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const trace_enabled = b.option(bool, "trace", "enable libc tracing") orelse false;
    const features = libcbuild.Features{
        .cstd = b.option(bool, "cstd", "Enable cstd in cguana (default: on)") orelse true,
        .gnu = b.option(bool, "gnu", "Enable cstd in cguana (default: off)") orelse true,
        .posix = b.option(bool, "posix", "Enable cstd in cguana (default: off)") orelse true,
        .linux = b.option(bool, "linux", "Enable cstd in cguana (default: off)") orelse true,
    };
    const static_build = b.option(bool, "static", "Enables static library (default: on)") orelse true;
    const dynamic_build = b.option(bool, "dynamic", "Enables dynamic library (default: on)") orelse true;
    const start_mode = b.option(libcbuild.Start, "start", "Selects the startup code (default: ziglibc)") orelse .ziglibc;

    {
        const exe = b.addExecutable(.{
            .name = "genheaders",
            .root_source_file = .{ .path = "src/genheaders.zig" },
        });
        const run = b.addRunArtifact(exe);
        run.addArg(b.pathFromRoot("capi.txt"));
        b.step("genheaders", "Generate C Headers").dependOn(&run.step);
    }

    const zig_start = libcbuild.addZigStart(b, target, optimize);
    b.installArtifact(zig_start);

    if (static_build) {
        const libc_full_static = libcbuild.addLibc(b, .{
            .features = features,
            .link = .static,
            .start = start_mode,
            .trace = trace_enabled,
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(libc_full_static);
    }

    if (dynamic_build) {
        const libc_full_shared = libcbuild.addLibc(b, .{
            .features = features,
            .link = .shared,
            .start = start_mode,
            .trace = trace_enabled,
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(libc_full_shared);
    }
}
