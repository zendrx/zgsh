const std = @import("std");
const ast = @import("ast.zig");
const lexer = @import("lexer.zig");

pub const ParseError = error{
    UnexpectedToken,
    OutOfMemory,
};

pub fn parse(line: []const u8, alloc: std.mem.Allocator) ParseError!ast.Ast {
    var lx = lexer.Lexer.init(line);
    var commands: std.ArrayList(ast.Command) = .empty;
    var current = ast.Command.init();
    var seen_pipe = false;

    while (try lx.next()) |tok| switch (tok) {
        .word => |w| {
            if (seen_pipe) {
                try commands.append(alloc, current);
                current = ast.Command.init();
                seen_pipe = false;
            }

            try current.addArg(.{ .text = w.text, .quoted = w.quoted }, alloc);
        },

        .pipe => {
            if (current.argv.items.len == 0) {
                return ParseError.UnexpectedToken;
            }
            try commands.append(alloc, current);
            current = ast.Command.init();
            seen_pipe = true;
        },

        .redirect_in, .redirect_out, .redirect_append => {
            if (seen_pipe) {
                try commands.append(alloc, current);
                current = ast.Command.init();
                seen_pipe = false;
            }

            const kind: ast.Redirkind = switch (tok) {
                .redirect_in => .input,
                .redirect_out => .outut,
                .redirect_append => .append,
                else => unreachable,
            };
            try current.addRedir(.{
                .fd = if (kind == .input) 0 orelse 1,
                .kind = kind,
                .path = tok.word.text,
            }, alloc);
        },
    };

    if (seen_pipe) {
        return ParseError.UnexpectedToken;
    }

    if (commands.items.len == 0) {
        if (current.argv.items.len == 0) {
            return ParseError.UnexpectedToken;
        }

        return .{ .stmt = .{ .simple = current } };
    }

    if (current.argv.items.len == 0) {
        return ParseError.UnexpectedToken;
    }

    try commands.append(alloc, current);
    return .{ .stmt = .{ .pipeline = .{ .commands = commands } } };
}
