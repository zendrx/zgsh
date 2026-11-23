const std = @import("std");
const ast = @import("ast.zig");
const lexer = @import("lexer.zig");

pub const ParseError = error{
    UnexpectedToken,
    OutOfMemory,
};

pub const Ast = struct {
    stmt: ast.Stmt,
};

pub fn parse(line: []const u8, alloc: std.mem.Allocator) ParseError!Ast {
    var lx = lexer.Lexer.init(line);
    var stmt = ast.Stmt{};
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
            if (current.args.items.len == 0) {
                return ParseError.UnexpectedToken;
            }
            try commands.append(alloc, current);
            current = ast.Command.init();
            seen_pipe = true;
        },

        .redirect_in, .redirect_out => {
            return ParseError.UnexpectedToken;
        },
    };

    if (seen_pipe) {
        return ParseError.UnexpectedToken;
    }

    if (commands.items.len == 0) {
        if (current.argv.items.len == 0) {
            return ParseError.UnexpectedToken;
        }

        return .{ .stmt = stmt };
    }

    if (current.argv.items.len == 0) {
        return ParseError.UnexpectedToken;
    }

    try commands.append(alloc, current);
    return .{ .stmt = .{ .pipeline = .{ .commands = commands } } };
}
