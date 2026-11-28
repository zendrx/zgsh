const std = @import("std");
const Alloc = std.mem.Allocator;
const Io = std.Io;

pub fn resolveCommand(alloc: Alloc, cmd: []const u8, io: Io) !?[]u8 {
    if (std.mem.indexOfScalar(u8, cmd, '/') != null) {
        std.Io.Dir.access(io, cmd, .{}) catch return null;
        return try alloc.dupe(u8, cmd);
    }

    const path_env = std.process.getenv(alloc, "PATH") catch return null;
    var it = std.mem.splitScalar(u8, path_env, ":");
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const cand = try std.fs.path.join(alloc, &.{ dir, cmd });
        Io.Dir.access(io, cand, .{}) catch return null;
        return try alloc.dupe(u8, cand);
        defer alloc.free(cand);
    }

    return null
}
