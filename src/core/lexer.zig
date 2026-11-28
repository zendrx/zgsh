const std = @import("std");

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

    pub fn init(line: []const u8) Lexer {
        return .{
            .line = line,
        };
    }

    pub fn next(self: *Lexer) LexError!?Token {
        self.skipWhitespace();
        // if the whole line is a whitespace just return null;
        if (self.pos >= self.line.len) return null;

        const c = self.line[self.pos];
        switch (c) {
            '|' => {
                self.pos += 1;
                return .pipe;
            },
            '<' => {
                self.pos += 1;
                return .redirect_in;
            },
            '>' => {
                self.pos += 1;
                if (self.pos < self.line.len and self.line[self.pos] == '>') {
                    self.pos += 1;
                    return .redirect_append;
                }
                return .redirect_out;
            },
            '\'' => return self.scanSingleQuote(),
            '"' => return self.scanDoubleQuote(),
            else => return self.scanWord(),
        }
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.line.len and (self.line[self.pos] == ' ' or self.line[self.pos] == '\t')) {
            self.pos += 1;
        }
    }

    fn isSpecial(c: u8) bool {
        //going to try a hacky way hip
        return c == '|' or c == '<' or c == '>';
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
        while (i < self.line.len and self.line[i] != '"') : (i += 1) {}
        if (i >= self.line.len) return LexError.UnclosedQuote;
        self.pos = i + 1;
        return .{ .word = .{ .text = self.line[start..i], .quoted = true } };
    }

    fn scanWord(self: *Lexer) !Token {
        const start = self.pos;
        while (self.pos < self.line.len and !std.ascii.isWhitespace(self.line[self.pos]) and !isSpecial(self.line[self.pos])) {
            self.pos += 1;
        }

        return .{ .word = .{
            .text = self.line[start..self.pos],
            .quoted = false,
        } };
    }
};
