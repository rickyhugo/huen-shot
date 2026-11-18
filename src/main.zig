const std = @import("std");
const Dir = std.Io.Dir;
const fatal = std.process.fatal;
const Config = @import("Config.zig");

const usage =
    \\Usage: huen-shot
    \\
    \\Drag a rectangle on the screen. huen-shot copies the screenshot to the clipboard.
    \\Press Escape to cancel.
    \\
    \\Config: ~/.config/huen-shot/config.toml
    \\  save_dir = "~/Pictures/Screenshots"   Also keep each screenshot in this directory.
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const arena = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);
    if (args.len > 1) {
        try std.Io.File.stderr().writeStreamingAll(io, usage);
        return 2;
    }

    const home = init.environ_map.get("HOME") orelse fatal("HOME is not set", .{});
    const config = try loadConfig(arena, io, home);

    const dir = config.save_dir orelse init.environ_map.get("TMPDIR") orelse "/tmp";
    // createDirPath fails with NotDir when the path is a symlink to a directory.
    Dir.cwd().access(io, dir, .{}) catch
        Dir.cwd().createDirPath(io, dir) catch |err| fatal("cannot create {s}: {t}", .{ dir, err });
    var name_buffer: [64]u8 = undefined;
    const path = try std.fs.path.joinZ(arena, &.{ dir, fileName(&name_buffer) });

    var screencapture = try std.process.spawn(io, .{
        .argv = &.{ "/usr/sbin/screencapture", "-s", path },
    });
    if (try screencapture.wait(io) != .exited) fatal("screencapture did not exit normally", .{});

    // screencapture exits 0 after a capture and after a cancel. Only a cancel leaves no file.
    Dir.cwd().access(io, path, .{}) catch return 1;
    const copied = copyPngToClipboard(path);
    if (config.save_dir == null) Dir.cwd().deleteFile(io, path) catch {};
    if (!copied) fatal("cannot copy the screenshot to the clipboard", .{});

    if (config.save_dir != null) {
        try std.Io.File.stdout().writeStreamingAll(io, try std.fmt.allocPrint(arena, "{s}\n", .{path}));
    }
    return 0;
}

fn loadConfig(arena: std.mem.Allocator, io: std.Io, home: []const u8) !Config {
    const path = try std.fs.path.join(arena, &.{ home, ".config/huen-shot/config.toml" });
    const text = Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20)) catch |err| switch (err) {
        error.FileNotFound => return .{},
        else => fatal("cannot read {s}: {t}", .{ path, err }),
    };
    var diagnostic: Config.Diagnostic = .{};
    return Config.parse(arena, text, home, &diagnostic) catch |err| switch (err) {
        error.InvalidConfig => fatal("{s}:{d}: {s}", .{ path, diagnostic.line, diagnostic.message }),
        error.OutOfMemory => |oom| return oom,
    };
}

fn fileName(buffer: *[64]u8) []const u8 {
    var now = time(null);
    var local: Tm = undefined;
    _ = localtime_r(&now, &local);
    return buffer[0..strftime(buffer, buffer.len, "huen-shot-%Y-%m-%d-%H%M%S.png", &local)];
}

const Tm = extern struct {
    sec: c_int,
    min: c_int,
    hour: c_int,
    mday: c_int,
    mon: c_int,
    year: c_int,
    wday: c_int,
    yday: c_int,
    isdst: c_int,
    gmtoff: c_long,
    zone: ?[*:0]const u8,
};

extern "c" fn time(result: ?*c_long) c_long;
extern "c" fn localtime_r(clock: *const c_long, result: *Tm) ?*Tm;
extern "c" fn strftime(buffer: [*]u8, max_len: usize, format: [*:0]const u8, tm: *const Tm) usize;

fn copyPngToClipboard(path: [:0]const u8) bool {
    const png = msgSend(fn (Id, Sel, Id) callconv(.c) Id)(
        objc_getClass("NSData"),
        sel_registerName("dataWithContentsOfFile:"),
        nsString(path),
    ) orelse return false;
    const pasteboard = msgSend(fn (Id, Sel) callconv(.c) Id)(
        objc_getClass("NSPasteboard"),
        sel_registerName("generalPasteboard"),
    );
    _ = msgSend(fn (Id, Sel) callconv(.c) isize)(pasteboard, sel_registerName("clearContents"));
    // BOOL is `signed char` on x86_64 and `bool` on arm64. `i8` reads both.
    return msgSend(fn (Id, Sel, Id, Id) callconv(.c) i8)(
        pasteboard,
        sel_registerName("setData:forType:"),
        png,
        nsString("public.png"),
    ) != 0;
}

fn nsString(text: [*:0]const u8) Id {
    return msgSend(fn (Id, Sel, [*:0]const u8) callconv(.c) Id)(
        objc_getClass("NSString"),
        sel_registerName("stringWithUTF8String:"),
        text,
    );
}

const Id = ?*opaque {};
const Sel = ?*opaque {};

extern "objc" fn objc_getClass(name: [*:0]const u8) Id;
extern "objc" fn sel_registerName(name: [*:0]const u8) Sel;
extern "objc" fn objc_msgSend() void;

fn msgSend(comptime Method: type) *const Method {
    return @ptrCast(&objc_msgSend);
}

test {
    _ = Config;
}
