const std = @import("std");
const Alloc = std.mem.Allocator;

pub const Arg = struct {
    text: []const u8,
    quoted: bool,
};

pub const RedirKind = enum {
    input,
    output,
    append,
};
pub const Redirect = struct {
    fd: u8,
    kind: RedirKind,
    path: []u8,
};

pub const Command = struct {
    argv: std.ArrayList(Arg),
    redirs: std.ArrayList(Redirect),

    pub fn init() Command {
        return .{ .argv = .empty, .redirs = .empty };
    }

    pub fn addArg(self: *Command, arg: Arg, alloc: Alloc) !void {
        try self.argv.append(alloc, arg);
    }

    pub fn addRedir(self: *Command, r: Redirect, alloc: Alloc) !void {
        try self.redirs.append(alloc, r);
    }
};

pub const Pipeline = struct {
    commands: std.ArrayList(Command),

    pub fn init() Pipeline {
        return .{ .commands = .empty };
    }
};

pub const Stmt = union(enum) {
    simple: Command,
    pipeline: Pipeline,
};

pub const Ast = struct {
    stmt: Stmt,
};

pub fn isEmpty(stmt: *const Stmt) bool {
    return switch (stmt.*) {
        .simple => |*cmd| cmd.argv.items.len == 0,
        .pipeline => |*p| p.commands.items.len == 0,
    };
}
