const std = @import("std");

pub fn build(builder: *std.Build) void {
    const root_module = builder.createModule(.{
        .root_source_file = builder.path("src/main.zig"),
        .target = builder.standardTargetOptions(.{}),
        .optimize = builder.standardOptimizeOption(.{}),
    });
    root_module.linkFramework("AppKit", .{});

    const exe = builder.addExecutable(.{ .name = "huen-shot", .root_module = root_module });
    builder.installArtifact(exe);

    const tests = builder.addTest(.{ .root_module = root_module });
    builder.step("test", "Run the tests").dependOn(&builder.addRunArtifact(tests).step);
}
