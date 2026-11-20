const std = @import("std");
const Io = std.Io;

const Shell = struct {
    alloc: std.mem.Allocator,
    io: Io,
    running: bool = true,
    last_status: u8 = 0,
    stdin: *Io.Reader,
    stdout: *Io.Writer,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc_gpa = init.gpa;
    var buffer: [1024]u8 = undefined;
    var bufferw: [1024]u8 = undefined;
    const reader = try Io.File.stdin().reader(io, &buffer).interface;
    const writer = Io.File.stdout().writer(io, &bufferw).interface;
    var shell = Shell{ .alloc = alloc_gpa, .io = io, .stdin = reader, .stdout = writer };

    //TODO: setupp termnal stdin ttyy
    while (shell.running) {
        try Io.File.stdout().writeStreamingAll(io, "kish> ");
        const line = try readline(&shell);
        defer shell.alloc.free(line);

        if (blank(line)) continue;

        shell.last_status = try eval(&shell, line);
    }

    //TODO: terminal state should be restored
}

fn blank(line: []const u8) bool {
    for (line) |l| {
        if (!std.ascii.isWhitespace(l)) return false;
    }

    return true;
}
