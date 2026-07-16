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
    text: []const u8,
    type: TokenType,
};

const Lexer = struct {
    code: [:0]const u8,
    pos: usize,

    pub fn init(code: [:0]const u8) Lexer {
        return Lexer{
            .code = code,
            .pos = 0,
        };
    }

    pub fn peek(self: *Lexer) Token {
        const temp = self.pos;
        const token = self.next();
        self.pos = temp;
        return  token;

    }
    pub fn next(self: *Lexer) Token {
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
                    ';' => {
                        token.type = .semicolon;
                        self.pos += 1;
                        text_end = self.pos;
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
                        text_end = self.pos;
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
                    'a'...'z', 'A'...'Z' => {
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
        }

        token.text = self.code[text_start..text_end];
        return token;
    }
};

fn tokenize(allocator: std.mem.Allocator, code: [:0]const u8) !std.MultiArrayList(Token) {
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

// peek vs next

test "peek is equal to next" {
    const code: [:0]const u8 = "a == b >= c <= d > e < f";
    var lexer = Lexer.init(code);

    while (true) {
        const peek = lexer.peek();
        const token = lexer.next();
        try testing.expect(std.meta.eql(peek ,token));
        if (token.type == .eof) {
            break;
        }
    }
}

// Can it lex correctly

test "sum" {
    const code: [:0]const u8 = "1 + 1";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .number, .plus, .number, .eof }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{ "1", "+", "1", "" }, list.items(.text));
}

test "variable defenition" {
    const code: [:0]const u8 = "let foo = 1";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .keyword_let, .identifier, .equal, .number, .eof }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{ "let", "foo", "=", "1", "" }, list.items(.text));
}

test "comparison operators" {
    const code: [:0]const u8 = "a == b >= c <= d > e < f";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .identifier,    .equal_equal, .identifier,
        .greater_equal, .identifier,  .less_equal,
        .identifier,    .greater,     .identifier,
        .less,          .identifier,  .eof,
    }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{
        "a", "==", "b",
        ">=", "c",  "<=",
        "d",  ">",  "e",
        "<",  "f",  "",
    }, list.items(.text));
}

test "string literal" {
    const code: [:0]const u8 = "\"hello\"";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .string_literal, .eof }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{ "\"hello\"", "" }, list.items(.text));
}

test "float number" {
    const code: [:0]const u8 = "3.14";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .number, .eof }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{ "3.14", "" }, list.items(.text));
}

test "punctuation" {
    const code: [:0]const u8 = "( ) { } [ ] , . ;";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .left_paren,  .right_paren,
        .left_brace,  .right_brace,
        .left_square, .right_square,
        .comma,       .dot,
        .semicolon,   .eof,
    }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{
        "(", ")", "{", "}", "[", "]", ",", ".", ";", "",
    }, list.items(.text));
}

test "keywords" {
    const code: [:0]const u8 = "if else while for return fun";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .keyword_if,  .keyword_else,   .keyword_while,
        .keyword_for, .keyword_return, .keyword_fun,
        .eof,
    }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{
        "if", "else", "while", "for", "return", "fun", "",
    }, list.items(.text));
}

test "empty input" {
    const code: [:0]const u8 = "";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{.eof}, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{""}, list.items(.text));
}

test "arithmetic operators" {
    const code: [:0]const u8 = "1 + 2 - 3";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .number, .plus, .number, .minus, .number, .eof,
    }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{ "1", "+", "2", "-", "3", "" }, list.items(.text));
}

test "function call" {
    const code: [:0]const u8 = "foo(a, b);";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .identifier, .left_paren,  .identifier, .comma,
        .identifier, .right_paren, .semicolon,  .eof,
    }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{
        "foo", "(", "a", ",", "b", ")", ";", "",
    }, list.items(.text));
}

test "boolean keywords" {
    const code: [:0]const u8 = "true false and or";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .keyword_true, .keyword_false, .keyword_and, .keyword_or, .eof,
    }, list.items(.type));
    try testing.expectEqualDeep( &[_][]const u8{ "true", "false", "and", "or", "" }, list.items(.text));
}
