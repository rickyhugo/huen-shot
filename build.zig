const std = @import("std");

pub fn build(b: *std.Build) void {
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    root_module.linkFramework("AppKit", .{});

    const exe = b.addExecutable(.{ .name = "huen-shot", .root_module = root_module });
    b.installArtifact(exe);

    const tests = b.addTest(.{ .root_module = root_module });
    b.step("test", "Run the tests").dependOn(&b.addRunArtifact(tests).step);
}
