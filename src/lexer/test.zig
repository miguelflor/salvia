const std = @import("std");
const root = @import("root.zig");
const Lexer = root.Lexer;
const TokenType = root.TokenType;
const tokenize = root.tokenize;
const testing = std.testing;

test "peek is equal to next" {
    const code: [:0]const u8 = "a == b >= c <= d > e < f";
    var lexer = Lexer.init(code);

    while (true) {
        const peek = lexer.peek();
        const token = lexer.next();
        try testing.expect(std.meta.eql(peek, token));
        if (token.type == .eof) {
            break;
        }
    }
}

test "sum" {
    const code: [:0]const u8 = "1 + 1";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .number, .plus, .number, .eof }, list.items(.type));
    try testing.expectEqualDeep(&[_][]const u8{ "1", "+", "1", "" }, list.items(.text));
}

test "variable defenition" {
    const code: [:0]const u8 = "let foo = 1";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .keyword_let, .identifier, .equal, .number, .eof }, list.items(.type));
    try testing.expectEqualDeep(&[_][]const u8{ "let", "foo", "=", "1", "" }, list.items(.text));
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
    try testing.expectEqualDeep(&[_][]const u8{
        "a",  "==", "b",
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
    try testing.expectEqualDeep(&[_][]const u8{ "\"hello\"", "" }, list.items(.text));
}

test "float number" {
    const code: [:0]const u8 = "3.14";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{ .number, .eof }, list.items(.type));
    try testing.expectEqualDeep(&[_][]const u8{ "3.14", "" }, list.items(.text));
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
    try testing.expectEqualDeep(&[_][]const u8{
        "(", ")", "{", "}", "[", "]", ",", ".", ";", "",
    }, list.items(.text));
}

test "keywords" {
    const code: [:0]const u8 = "if else while for return proc";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .keyword_if,  .keyword_else,   .keyword_while,
        .keyword_for, .keyword_return, .keyword_proc,
        .eof,
    }, list.items(.type));
    try testing.expectEqualDeep(&[_][]const u8{
        "if", "else", "while", "for", "return", "proc", "",
    }, list.items(.text));
}

test "empty input" {
    const code: [:0]const u8 = "";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{.eof}, list.items(.type));
    try testing.expectEqualDeep(&[_][]const u8{""}, list.items(.text));
}

test "arithmetic operators" {
    const code: [:0]const u8 = "1 + 2 - 3";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .number, .plus, .number, .minus, .number, .eof,
    }, list.items(.type));
    try testing.expectEqualDeep(&[_][]const u8{ "1", "+", "2", "-", "3", "" }, list.items(.text));
}

test "function call" {
    const code: [:0]const u8 = "foo(a, b);";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .identifier, .left_paren,  .identifier, .comma,
        .identifier, .right_paren, .semicolon,  .eof,
    }, list.items(.type));
    try testing.expectEqualDeep(&[_][]const u8{
        "foo", "(", "a", ",", "b", ")", ";", "",
    }, list.items(.text));
}

test "boolean operators" {
    const code: [:0]const u8 = "true \\/ false /\\";
    var list = try tokenize(testing.allocator, code);
    defer list.deinit(testing.allocator);
    try testing.expectEqualSlices(TokenType, &[_]TokenType{
        .keyword_true, .or_op, .keyword_false, .and_op, .eof,
    }, list.items(.type));
    try testing.expectEqualDeep(&[_][]const u8{ "true", "\\/", "false", "/\\", "" }, list.items(.text));
}
