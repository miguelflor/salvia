const std = @import("std");
const testing = std.testing;

const State = enum { start, identifier, less, greater, string, equal, int, int_dot, float };

const TokenType = enum {
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
    minus,
    plus,
    semicolon,

    // one or two character tokens.
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,

    // literals
    identifier,
    string_literal,
    number,

    // keywords.
    keyword_and,
    keyword_struct,
    keyword_else,
    keyword_false,
    keyword_fun,
    keyword_for,
    keyword_if,
    keyword_nil,
    keyword_or,
    keyword_return,
    keyword_this,
    keyword_true,
    keyword_var,
    keyword_while,

    eof,
};

const keywordStr = std.StaticStringMap(TokenType).initComptime(.{
    .{ "and", .keyword_and },
    .{ "struct", .keyword_struct },
    .{ "else", .keyword_else },
    .{ "false", .keyword_false },
    .{ "fun", .keyword_fun },
    .{ "for", .keyword_for },
    .{ "if", .keyword_if },
    .{ "nil", .keyword_nil },
    .{ "or", .keyword_or },
    .{ "return", .keyword_return },
    .{ "this", .keyword_this },
    .{ "true", .keyword_true },
    .{ "var", .keyword_var },
    .{ "while", .keyword_while },
});

fn getKeywordToken(keyword: []const u8) ?TokenType {
    return keywordStr.get(keyword);
}

const Token = struct {
    start: usize,
    end: usize,
    type: TokenType,
};

const Scanner = struct {
    code: [:0]const u8,
    pos: usize,

    pub fn init(code: [:0]const u8) Scanner {
        return Scanner{
            .code = code,
            .pos = 0,
        };
    }

    pub fn next(self: *Scanner) Token {
        var token = Token{
            .start = self.pos,
            .end = undefined,
            .type = undefined,
        };
        state: switch (State.start) {
            .start => {
                switch (self.code[self.pos]) {
                    0 => {
                        if (self.code.len == self.pos) {
                            token.type = .eof;
                        } else {
                            self.pos += 1;
                            token.type = .invalid;
                        }
                    },
                    ' ', '\r', '\n', '\t' => {
                        self.pos += 1;
                        token.start=self.pos;
                        continue :state .start;
                    },
                    '0'...'9' => {
                        self.pos+=1;
                        token.type = .number;
                        continue :state .int;
                    },
                    'a'...'z', 'A'...'Z' => {
                        continue :state .identifier;
                    },
                    '[' => {
                        token.type = .left_square;
                        self.pos += 1;
                    },
                    ']' => {
                        token.type = .right_square;
                        self.pos += 1;
                    },
                    '(' => {
                        token.type = .left_paren;
                        self.pos += 1;
                    },
                    ')' => {
                        token.type = .right_paren;
                        self.pos += 1;
                    },
                    '{' => {
                        token.type = .left_brace;
                        self.pos += 1;
                    },
                    '}' => {
                        token.type = .right_brace;
                        self.pos += 1;
                    },

                    '+' => {
                        token.type = .plus;
                        self.pos += 1;
                    },
                    '-' => {
                        token.type = .minus;
                        self.pos += 1;
                    },
                    ',' => {
                        token.type = .comma;
                        self.pos += 1;
                    },
                    '.' => {
                        token.type = .dot;
                        self.pos += 1;
                    },
                    ';' => {
                        token.type = .semicolon;
                        self.pos += 1;
                    },
                    '=' => {
                        token.type = .equal;
                        continue :state .equal;
                    },
                    '>' => {
                        token.type = .greater;
                        continue :state .greater;
                    },
                    '<' => {
                        token.type = .less;
                        continue :state .less;
                    },
                    '"' => {
                        token.type = .string_literal;
                        continue :state .string;
                    },
                    else => {
                        self.pos += 1;
                        token.type = .invalid;
                    },
                }
            },
            .equal => {
                switch (self.code[self.pos]) {
                    '=' => {
                        self.pos += 1;
                        token.type = .equal_equal;
                    },
                    else => {
                        self.pos += 1;
                    },
                }
            },
            .greater => {
                switch (self.code[self.pos]) {
                    '=' => {
                        self.pos += 1;
                        token.type = .greater_equal;
                    },
                    else => {
                        self.pos += 1;
                    },
                }
            },
            .less => {
                switch (self.code[self.pos]) {
                    '=' => {
                        self.pos += 1;
                        token.type = .less_equal;
                    },
                    else => {
                        self.pos += 1;
                    },
                }
            },
            .identifier => {
                switch (self.code[self.pos]) {
                    'a'...'z', 'A'...'Z' => {
                        self.pos += 1;
                        continue :state .identifier;
                    },
                    else => {
                        token.type = getKeywordToken(self.code[token.start..self.pos]) orelse .identifier;
                        self.pos += 1;
                    },
                }
            },
            .string => {
                switch (self.code[self.pos]) {
                    0 => {
                        token.type = .unclosed_string;
                    },
                    '"' => {
                        self.pos += 1;
                        token.type = .string_literal;
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
                    else => {},
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
                        self.pos += 1;
                    },
                }
            },
        }

        token.end = self.pos;
        return token;
    }
};

pub fn tokenize(allocator: std.mem.Allocator, code: [:0]const u8) !std.MultiArrayList(Token) {
    var scanner = Scanner.init(code);
    var list: std.MultiArrayList(Token) = .empty;

    while (true) {
        const token = scanner.next();
        try list.append(allocator, token);
        if (token.type == .eof) {
            break;
        }
    }

    return list;
}

// Tests

test "variable token" {
    const code: [:0]const u8 = "1 + 1";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .number, .plus, .number, .eof },list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 2, 4, 5 }, list.items(.start));
}
