const std = @import("std");

const State = enum {
    start,
    identifier,
    less,
    greater,
    string,
    equal,
    int,
    int_dot,
    float,
    not_diff,
    backslash,
    slash,
};

pub const TokenType = enum {
    invalid,
    unclosed_string,
    // Single-character tokens.
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    left_square,
    right_square,
    comma,
    dot,
    semicolon,
    colon,

    // Ops
    minus,
    plus,
    mult,

    // one or two character tokens.
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,
    not,
    diff,
    and_op,
    or_op,

    // literals
    identifier,
    string_literal,
    number,

    // keywords.
    keyword_struct,
    keyword_set,
    keyword_protocol,
    keyword_impl,
    keyword_with,
    keyword_extend,
    keyword_else,
    keyword_elif,
    keyword_false,
    keyword_proc,
    keyword_upon,
    keyword_for,
    keyword_if,
    keyword_nil,
    keyword_return,
    keyword_this,
    keyword_true,
    keyword_let,
    keyword_while,

    eof,
};

const keywordStr = std.StaticStringMap(TokenType).initComptime(.{
    .{ "struct", .keyword_struct },
    .{ "set", .keyword_set },
    .{ "protocol", .keyword_protocol },
    .{ "impl", .keyword_impl },
    .{ "with", .keyword_with },
    .{ "extend", .keyword_extend },
    .{ "else", .keyword_else },
    .{ "elif", .keyword_elif },
    .{ "false", .keyword_false },
    .{ "proc", .keyword_proc },
    .{ "upon", .keyword_upon },
    .{ "for", .keyword_for },
    .{ "if", .keyword_if },
    .{ "nil", .keyword_nil },
    .{ "return", .keyword_return },
    .{ "this", .keyword_this },
    .{ "true", .keyword_true },
    .{ "let", .keyword_let },
    .{ "while", .keyword_while },
});

fn getKeywordToken(keyword: []const u8) ?TokenType {
    return keywordStr.get(keyword);
}

pub const Token = struct {
    text: []const u8,
    type: TokenType,
};

pub const Lexer = struct {
    code: [:0]const u8,
    pos: usize,
    peaked: ?struct { token: Token, pos: usize },

    pub fn init(code: [:0]const u8) Lexer {
        return Lexer{
            .code = code,
            .pos = 0,
            .peaked = null,
        };
    }

    pub fn peek(self: *Lexer) Token {
        if (self.peaked) |peaked| return peaked.token;
        const temp = self.pos;
        const token = self.next();
        self.peaked = .{ .token = token, .pos = self.pos };
        self.pos = temp;
        return token;
    }
    pub fn next(self: *Lexer) Token {
        if (self.peaked) |peaked| {
            const tmp = peaked.token;
            self.peaked = null;
            self.pos = peaked.pos;
            return tmp;
        }

        var text_start = self.pos;
        var text_end: usize = undefined;

        var token = Token{
            .text = undefined,
            .type = undefined,
        };

        state: switch (State.start) {
            .start => {
                switch (self.code[self.pos]) {
                    0 => {
                        if (self.code.len == self.pos) {
                            token.type = .eof;
                            text_end = self.pos;
                        } else {
                            self.pos += 1;
                            token.type = .invalid;
                            text_end = self.pos;
                        }
                    },
                    ' ', '\r', '\n', '\t' => {
                        self.pos += 1;
                        text_start = self.pos;
                        continue :state .start;
                    },
                    '0'...'9' => {
                        self.pos += 1;
                        token.type = .number;
                        continue :state .int;
                    },
                    'a'...'z', 'A'...'Z' => {
                        self.pos += 1;
                        continue :state .identifier;
                    },
                    '[' => {
                        token.type = .left_square;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    ']' => {
                        token.type = .right_square;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    '(' => {
                        token.type = .left_paren;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    ')' => {
                        token.type = .right_paren;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    '{' => {
                        token.type = .left_brace;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    '}' => {
                        token.type = .right_brace;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    '+' => {
                        token.type = .plus;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    '*' => {
                        token.type = .mult;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    '-' => {
                        token.type = .minus;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    ',' => {
                        token.type = .comma;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    '.' => {
                        token.type = .dot;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    ':' => {
                        token.type = .colon;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    ';' => {
                        token.type = .semicolon;
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    '\\' => {
                        self.pos += 1;
                        continue :state .backslash;
                    },
                    '/' => {
                        self.pos += 1;
                        continue :state .slash;
                    },
                    '=' => {
                        self.pos += 1;
                        token.type = .equal;
                        continue :state .equal;
                    },
                    '>' => {
                        self.pos += 1;
                        token.type = .greater;
                        continue :state .greater;
                    },
                    '<' => {
                        self.pos += 1;
                        token.type = .less;
                        continue :state .less;
                    },
                    '!' => {
                        token.type = .not;
                        self.pos += 1;
                        continue :state .not_diff;
                    },
                    '"' => {
                        self.pos += 1;
                        token.type = .string_literal;
                        continue :state .string;
                    },
                    else => {
                        self.pos += 1;
                        text_end = self.pos;
                        token.type = .invalid;
                    },
                }
            },
            .not_diff => {
                switch (self.code[self.pos]) {
                    '=' => {
                        self.pos += 1;
                        token.type = .diff;
                    },
                    else => {},
                }
                text_end = self.pos;
            },
            .equal => {
                switch (self.code[self.pos]) {
                    '=' => {
                        self.pos += 1;
                        token.type = .equal_equal;
                    },
                    else => {},
                }
                text_end = self.pos;
            },
            .greater => {
                switch (self.code[self.pos]) {
                    '=' => {
                        self.pos += 1;
                        token.type = .greater_equal;
                    },
                    else => {},
                }
                text_end = self.pos;
            },
            .less => {
                switch (self.code[self.pos]) {
                    '=' => {
                        self.pos += 1;
                        token.type = .less_equal;
                    },
                    else => {},
                }
                text_end = self.pos;
            },
            .identifier => {
                switch (self.code[self.pos]) {
                    'a'...'z', 'A'...'Z', '0'...'9' => {
                        self.pos += 1;
                        continue :state .identifier;
                    },
                    else => {
                        token.type = getKeywordToken(self.code[text_start..self.pos]) orelse .identifier;
                        text_end = self.pos;
                    },
                }
            },
            .string => {
                switch (self.code[self.pos]) {
                    0 => {
                        token.type = .unclosed_string;
                        text_end = self.pos;
                    },
                    '"' => {
                        self.pos += 1;
                        text_end = self.pos;
                    },
                    else => {
                        self.pos += 1;
                        continue :state .string;
                    },
                }
            },
            .int => {
                switch (self.code[self.pos]) {
                    '0'...'9' => {
                        self.pos += 1;
                        continue :state .int;
                    },
                    '.' => {
                        self.pos += 1;
                        continue :state .int_dot;
                    },
                    else => {
                        text_end = self.pos;
                    },
                }
            },
            .int_dot => {
                switch (self.code[self.pos]) {
                    '0'...'9' => {
                        self.pos += 1;
                        continue :state .float;
                    },
                    else => {
                        self.pos -= 1;
                        text_end = self.pos;
                    },
                }
            },
            .float => {
                switch (self.code[self.pos]) {
                    '0'...'9' => {
                        self.pos += 1;
                        continue :state .float;
                    },
                    else => {
                        text_end = self.pos;
                    },
                }
            },
            .backslash => {
                switch (self.code[self.pos]) {
                    '/' => {
                        self.pos += 1;
                        token.type = .or_op;
                    },
                    else => {
                        token.type = .invalid;
                    },
                }
                text_end = self.pos;
            },
            .slash => {
                switch (self.code[self.pos]) {
                    '\\' => {
                        self.pos += 1;
                        token.type = .and_op;
                    },
                    else => {
                        token.type = .invalid;
                    },
                }
                text_end = self.pos;
            },
        }

        token.text = self.code[text_start..text_end];
        return token;
    }
};

pub fn tokenize(allocator: std.mem.Allocator, code: [:0]const u8) !std.MultiArrayList(Token) {
    var lexer = Lexer.init(code);
    var list: std.MultiArrayList(Token) = .empty;

    while (true) {
        const token = lexer.next();
        try list.append(allocator, token);
        if (token.type == .eof) {
            break;
        }
    }

    return list;
}

// Tests
test {
    _ = @import("test.zig");
}
