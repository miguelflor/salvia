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
    keyword_let,
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
    .{ "let", .keyword_let },
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
                    '"' => {
                        self.pos += 1;
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

test "sum" {
    const code: [:0]const u8 = "1 + 1";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .number, .plus, .number, .eof }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 2, 4, 5 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 1, 3, 5, 5 }, list.items(.end));
}

test "variable defenition" {
    const code: [:0]const u8 = "let foo = 1";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .keyword_let, .identifier, .equal, .number, .eof }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 4, 8, 10, 11 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 4, 8, 10, 11, 11 }, list.items(.end));
}

test "comparison operators" {
    const code: [:0]const u8 = "a == b >= c <= d > e < f";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .identifier, .equal_equal, .identifier,
        .greater_equal, .identifier, .less_equal,
        .identifier, .greater, .identifier,
        .less, .identifier, .eof,
    }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 2, 5, 7, 10, 12, 15, 17, 19, 21, 23, 25 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 2, 4, 7, 9, 12, 14, 17, 19, 21, 23, 25, 25 }, list.items(.end));
}

test "string literal" {
    const code: [:0]const u8 = "\"hello\"";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .string_literal, .eof }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 7 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 7, 7 }, list.items(.end));
}

test "float number" {
    const code: [:0]const u8 = "3.14";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .number, .eof }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 4 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 4, 4 }, list.items(.end));
}

test "punctuation" {
    const code: [:0]const u8 = "( ) { } [ ] , . ;";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .left_paren, .right_paren,
        .left_brace, .right_brace,
        .left_square, .right_square,
        .comma, .dot, .semicolon,
        .eof,
    }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 2, 4, 6, 8, 10, 12, 14, 16, 17 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 1, 3, 5, 7, 9, 11, 13, 15, 17, 17 }, list.items(.end));
}

test "keywords" {
    const code: [:0]const u8 = "if else while for return fun";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .keyword_if, .keyword_else, .keyword_while,
        .keyword_for, .keyword_return, .keyword_fun,
        .eof,
    }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 3, 8, 14, 18, 25, 29 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 3, 8, 14, 18, 25, 29, 29 }, list.items(.end));
}

test "empty input" {
    const code: [:0]const u8 = "";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{.eof}, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{0}, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{0}, list.items(.end));
}

test "arithmetic operators" {
    const code: [:0]const u8 = "1 + 2 - 3";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .number, .plus, .number, .minus, .number, .eof,
    }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 2, 4, 6, 8, 9 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 1, 3, 5, 7, 9, 9 }, list.items(.end));
}

test "function call" {
    const code: [:0]const u8 = "foo(a, b);";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .identifier, .left_paren, .identifier, .comma,
        .identifier, .right_paren, .semicolon, .eof,
    }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 3, 4, 5, 7, 8, 9, 10 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 3, 4, 5, 6, 8, 9, 10, 10 }, list.items(.end));
}

test "boolean keywords" {
    const code: [:0]const u8 = "true false and or";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .keyword_true, .keyword_false, .keyword_and, .keyword_or, .eof,
    }, list.items(.type));
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 5, 11, 15, 18 }, list.items(.start));
    try testing.expectEqualSlices(usize, &[_]usize{ 5, 11, 15, 18, 18 }, list.items(.end));
}
