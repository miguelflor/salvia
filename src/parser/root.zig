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

const UniOpKind = enum {
    minus,
    diff,

    fn FromToken(token: lexer.TokenType) errors.ParseError!UniOpKind {
        return switch (token) {
            .minus => .minus,
            .diff => .diff,
            else => error.NotUnaryOp,
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

const Expr = union(enum) { basic_lit: struct { BasicLitKind, []const u8 }, bin_op: struct { BinOpKind, *Expr, *Expr }, uni_op: struct { UniOpKind, *Expr } };

const Bp = struct { l: u8, r: u8 };

const State = enum { prefix, loop, bin_op, post_uni_op };

// returns an expression tree, free whatever alloc uses, for example with arena
pub fn parse(alloc: std.mem.Allocator, code: [:0]const u8) errors.ParseError!Expr {
    var lex = lexer.Lexer.init(code);
    return try expr_bp(alloc, &lex, 0);
}

fn expr_bp(alloc: std.mem.Allocator, lex: *lexer.Lexer, min_bp: u8) errors.ParseError!Expr {
    var lhs: Expr = undefined;

    state: switch (State.prefix) {
        .prefix => {
            const token = lex.next();
            lhs = try switch (token.type) {
                .number => Expr{ .basic_lit = .{ try BasicLitKind.FromToken(token), token.text } },
                .minus => blk: {
                    const bp = try prefix_bp(token.type);
                    const rhs = try alloc.create(Expr);
                    rhs.* = try expr_bp(alloc, lex, bp.r);
                    break :blk Expr{ .uni_op = .{ try UniOpKind.FromToken(token.type), rhs } };
                },
                .left_paren => blk: {
                    const rhs = try expr_bp(alloc, lex, 0);
                    const t = lex.next();
                    if (t.type != .right_paren) return error.ExpectedRParen;
                    break :blk rhs;

                },
                else => error.UnexpectedToken,
            };
            continue :state .loop;
        },
        .loop => {
            switch (lex.peek().type) {
                .eof, .right_paren => return lhs,
                .minus, .plus, .mult => continue :state .bin_op,
                .diff => continue :state .post_uni_op,
                else => return error.NotImplemented,
            }
        },
        .bin_op => {
            const peek = lex.peek();
            const op = try BinOpKind.FromToken(peek.type);
            const bp = try infix_bp(peek.type);
            if (bp.l < min_bp) return lhs;

            _ = lex.next();
            const rhs_node = try alloc.create(Expr);
            rhs_node.* = try expr_bp(alloc, lex, bp.r);
            const lhs_node = try alloc.create(Expr);
            lhs_node.* = lhs;
            lhs = .{ .bin_op = .{ op, lhs_node, rhs_node } };
            continue :state .loop;
        },
        .post_uni_op => {
            const peek = lex.peek();
            const op = try UniOpKind.FromToken(peek.type);
            const bp = try postfix_bp(peek.type);
            if (bp.l < min_bp) return lhs;

            _ = lex.next();
            const lhs_node = try alloc.create(Expr);
            lhs_node.* = lhs;
            lhs = .{ .uni_op = .{ op, lhs_node } };
            continue :state .loop;
        },
    }
}

fn postfix_bp(op: lexer.TokenType) errors.ParseError!Bp {
    return switch (op) {
        .diff => Bp{ .l = 6, .r = undefined },
        else => error.UnexpectedToken,
    };
}

fn prefix_bp(op: lexer.TokenType) errors.ParseError!Bp {
    return switch (op) {
        .minus => Bp{ .l = undefined, .r = 5 },
        else => error.UnexpectedToken,
    };
}

fn infix_bp(op: lexer.TokenType) errors.ParseError!Bp {
    return switch (op) {
        .minus, .plus => Bp{ .l = 1, .r = 2 },
        .mult => Bp{ .l = 3, .r = 4 },
        else => error.UnexpectedToken,
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

test "parse: parenthesized expression" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "(42)");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.int, result.basic_lit[0]);
    try testing.expectEqualStrings("42", result.basic_lit[1]);
}

test "parse: parens override precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    // (1 + 2) * 3 should parse as (* (+ 1 2) 3), not (+ 1 (* 2 3))
    const result = try parse(arena.allocator(), "(1 + 2) * 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op[0]);
    try testing.expect(result.bin_op[1].* == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op[1].bin_op[0]);
    try testing.expectEqualStrings("1", result.bin_op[1].bin_op[1].basic_lit[1]);
    try testing.expectEqualStrings("2", result.bin_op[1].bin_op[2].basic_lit[1]);
    try testing.expectEqualStrings("3", result.bin_op[2].basic_lit[1]);
}

test "parse: postfix ! binds tighter than +" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    // 2 + 3! should parse as 2 + (3!), not (2 + 3)!
    const result = try parse(arena.allocator(), "2 + 3!");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op[0]);
    try testing.expectEqualStrings("2", result.bin_op[1].basic_lit[1]);
    try testing.expect(result.bin_op[2].* == .uni_op);
    try testing.expectEqual(UniOpKind.diff, result.bin_op[2].uni_op[0]);
    try testing.expectEqualStrings("3", result.bin_op[2].uni_op[1].basic_lit[1]);
}
