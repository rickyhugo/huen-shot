const std = @import("std");
const mem = std.mem;

const Config = @This();

/// The directory that keeps screenshots. `null` keeps them in the clipboard only.
save_dir: ?[]const u8 = null,

pub const Diagnostic = struct {
    line: usize = 0,
    message: []const u8 = "",
};

pub const ParseError = error{ InvalidConfig, OutOfMemory };

/// Parses the TOML subset that huen-shot uses: comments and `key = "string"` pairs.
/// Expands a leading `~` in `save_dir` to `home`.
pub fn parse(
    arena: mem.Allocator,
    text: []const u8,
    home: []const u8,
    diagnostic: *Diagnostic,
) ParseError!Config {
    var config: Config = .{};
    var lines = mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        diagnostic.line += 1;
        const line = trim(raw_line);
        if (line.len == 0 or line[0] == '#') continue;

        const equals = mem.indexOfScalar(u8, line, '=') orelse
            return fail(diagnostic, "expected `key = \"value\"`");
        const key = trim(line[0..equals]);
        const value = try parseString(trim(line[equals + 1 ..]), diagnostic);

        if (!mem.eql(u8, key, "save_dir")) return fail(diagnostic, "unknown key");
        if (config.save_dir != null) return fail(diagnostic, "duplicate key");
        config.save_dir = try expandHome(arena, value, home, diagnostic);
    }
    return config;
}

fn parseString(source: []const u8, diagnostic: *Diagnostic) ParseError![]const u8 {
    if (source.len == 0 or (source[0] != '"' and source[0] != '\''))
        return fail(diagnostic, "expected a quoted string");
    const quote = source[0];
    const end = mem.indexOfScalarPos(u8, source, 1, quote) orelse
        return fail(diagnostic, "unterminated string");
    const value = source[1..end];
    if (quote == '"' and mem.indexOfScalar(u8, value, '\\') != null)
        return fail(diagnostic, "escape sequences are not supported, use single quotes");
    const rest = trim(source[end + 1 ..]);
    if (rest.len != 0 and rest[0] != '#')
        return fail(diagnostic, "unexpected text after the string");
    return value;
}

fn expandHome(
    arena: mem.Allocator,
    path: []const u8,
    home: []const u8,
    diagnostic: *Diagnostic,
) ParseError![]const u8 {
    if (mem.eql(u8, path, "~")) return home;
    if (mem.startsWith(u8, path, "~/")) return std.fs.path.join(arena, &.{ home, path[2..] });
    if (std.fs.path.isAbsolute(path)) return path;
    return fail(diagnostic, "save_dir must be an absolute path or start with ~/");
}

fn trim(text: []const u8) []const u8 {
    return mem.trim(u8, text, " \t\r");
}

fn fail(diagnostic: *Diagnostic, message: []const u8) error{InvalidConfig} {
    diagnostic.message = message;
    return error.InvalidConfig;
}

const testing = std.testing;

fn expectSaveDir(expected: ?[]const u8, text: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diagnostic: Diagnostic = .{};
    const config = try parse(arena.allocator(), text, "/Users/me", &diagnostic);
    if (expected) |dir| {
        try testing.expectEqualStrings(dir, config.save_dir.?);
    } else {
        try testing.expectEqual(null, config.save_dir);
    }
}

fn expectInvalid(line: usize, text: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diagnostic: Diagnostic = .{};
    try testing.expectError(error.InvalidConfig, parse(arena.allocator(), text, "/Users/me", &diagnostic));
    try testing.expectEqual(line, diagnostic.line);
}

test "an empty or comment-only file keeps screenshots in the clipboard only" {
    try expectSaveDir(null, "");
    try expectSaveDir(null, "# save_dir = \"/tmp\"\n\n");
}

test "save_dir accepts both string forms and a trailing comment" {
    try expectSaveDir("/tmp/shots", "save_dir = \"/tmp/shots\"\n");
    try expectSaveDir("/tmp/my shots", "  save_dir='/tmp/my shots' # keep\r\n");
}

test "save_dir expands a leading tilde to the home directory" {
    try expectSaveDir("/Users/me/Pictures/Screenshots", "save_dir = \"~/Pictures/Screenshots\"");
    try expectSaveDir("/Users/me", "save_dir = \"~\"");
}

test "invalid input reports the line that failed" {
    try expectInvalid(1, "save_dir = relative/path");
    try expectInvalid(1, "save_dir = \"relative/path\"");
    try expectInvalid(1, "save_dir = \"/tmp/unterminated");
    try expectInvalid(1, "save_dir = \"/tmp\" trailing");
    try expectInvalid(1, "save_dir = \"C:\\\\shots\"");
    try expectInvalid(2, "# comment\nsave_directory = \"/tmp\"");
    try expectInvalid(3, "\n\n[save]");
    try expectInvalid(2, "save_dir = '/a'\nsave_dir = '/b'");
}
