const std = @import("std");
const Alloc: std.mem.Allocator;

pub const Token = union(enum) {
    word: struct {
        text: []const u8,
        quoted: bool,
    },
    pipe,
    redirect_in,
    redirect_out,
    redirect_append,
};

pub const LexError = error{
    UnclosedQuote,
    OutOfMemory,
};

pub const Lexer = struct {
    line: []const u8,
    pos: usize = 0,
    alloc: Alloc,

    pub fn init(alloc: Alloc, line: []const u8) Lexer {
        return .{ .line = line, .alloc = alloc };
    }

    pub fn next(self: *Lexer) LexError!?Token {
        self.skipWhitespace();
        // if the whole line is a whitespace just return null;
        if (self.pos >= self.line.len) return null;
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.line.len and (self.line[self.pos] == ' ' or self.line[self.pos] == '\t')) {
            self.pos += 1;
        }
    }

    fn isSpecial(c: u8) bool {
        //going to try a hacky way hip
        if (c == '|' or c == '<' or c == '>') {
            return true;
        }
        return false;
    }

    fn scanSingleQuote(self: *Lexer) LexError!Token {
        // no escape shoud be inside a single quote posix rule
        const start = self.pos + 1;
        var i = start;
        while (i < self.line.len and self.line[i] != '\'') : (i += 1) {}
        if (i >= self.line.len) return LexError.UnclosedQuote;

        self.pos = i + 1;
        return .{ .word = .{ .text = self.line[start..i], .quoted = true } };
    }

    fn scanDoubleQuote(self: *Lexer) LexError!Token {
        const start = self.pos + 1;
        var i = start;
        while (i < self.line.len and self.line[i] != '""') : (i += 1) {}
        if (i >= self.line.len) return LexError.UnclosedQuote;
        self.pos = i + 1;
        return .{ .word = .{ .text = self.line[start..i], .quoted = true } };
    }
};
