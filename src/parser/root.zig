const lexer = @import("lexer");
const std = @import("std");
const errors = @import("errors");

const BinOpKind = enum {
    equal,
    greater,
    greater_equal,
    less,
    less_equal,
    minus,
    plus,
    mult,

    fn FromToken(token: lexer.TokenType) errors.ParseError!BinOpKind {
        return switch (token) {
            .equal => .equal,
            .greater => .greater,
            .greater_equal => .greater_equal,
            .less => .less,
            .less_equal => .less_equal,
            .minus => .minus,
            .plus => .plus,
            .mult => .mult,
            else => error.NotBinaryOp,
        };
    }
};

const BasicLitKind = enum {
    float,
    string,
    int,

    fn FromToken(token: lexer.Token) errors.ParseError!BasicLitKind {
        return switch (token.type) {
            .number => {
                _ = std.mem.indexOfScalar(u8, token.text, '.') orelse return .int;
                return .float;
            },
            .string_literal => .string,
            else => error.NotBasicLit,
        };
    }
};

const Expr = union(enum) {
    basic_lit: struct { BasicLitKind, []const u8 },
    bin_op: struct { BinOpKind, *Expr, *Expr },
};

const Bp = struct { l: u8, r: u8 };

pub fn parse(alloc: std.mem.Allocator, code: [:0]const u8) errors.ParseError!Expr {
    var lex = lexer.Lexer.init(code);
    return try expr_bp(alloc, &lex, 0);
}

fn expr_bp(alloc: std.mem.Allocator, lex: *lexer.Lexer, min_bp: u8) errors.ParseError!Expr {
    const token = lex.next();
    var lhs: Expr = try switch (token.type) {
        .number => Expr{ .basic_lit = .{ try BasicLitKind.FromToken(token), token.text } },
        else => error.UnexpectedToken,
    };

    while (true) {
        const peek = lex.peek();
        const op = try switch (peek.type) {
            .eof => break,
            .minus, .plus, .mult => BinOpKind.FromToken(peek.type),
            else => return error.NotImplemented,
        };

        const bp = try infix_bp(op);
        if (bp.l < min_bp) {
            break;
        }
        _ = lex.next();
        const rhs_node = try alloc.create(Expr);
        rhs_node.* = try expr_bp(alloc,lex, bp.r);

        const lhs_node = try alloc.create(Expr);
        lhs_node.* = lhs;

        lhs = .{ .bin_op = .{ op, lhs_node, rhs_node } };
    }

    return lhs;
}

fn infix_bp(op: BinOpKind) errors.ParseError!Bp {
    return switch (op) {
        .minus, .plus => Bp{ .l = 1, .r = 2 },
        .mult => Bp{ .l = 3, .r = 4 },
        else => error.NotImplemented,
    };
}

const testing = std.testing;

test "parse: single integer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "42");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.int, result.basic_lit[0]);
    try testing.expectEqualStrings("42", result.basic_lit[1]);
}

test "parse: single float" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "3.14");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.float, result.basic_lit[0]);
    try testing.expectEqualStrings("3.14", result.basic_lit[1]);
}

test "parse: addition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op[0]);
    try testing.expectEqualStrings("1", result.bin_op[1].basic_lit[1]);
    try testing.expectEqualStrings("2", result.bin_op[2].basic_lit[1]);
}

test "parse: subtraction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "5 - 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.minus, result.bin_op[0]);
}

test "parse: multiplication" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "2 * 4");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op[0]);
}

test "parse: mult binds tighter than plus" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2 * 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op[0]);
    try testing.expect(result.bin_op[2].* == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op[2].bin_op[0]);
}

test "parse: plus is left-associative" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2 + 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op[0]);
    try testing.expect(result.bin_op[1].* == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op[1].bin_op[0]);
}
