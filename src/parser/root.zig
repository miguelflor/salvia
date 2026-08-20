const lexer = @import("lexer");
const std = @import("std");
const errors = @import("errors");

// Expressions structs

const BinOpKind = enum {
    equal,
    greater,
    greater_equal,
    less,
    less_equal,
    minus,
    plus,
    mult,

    fn fromToken(token: lexer.TokenType) errors.ParseError!BinOpKind {
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
    not,

    fn fromToken(token: lexer.TokenType) errors.ParseError!UniOpKind {
        return switch (token) {
            .minus => .minus,
            .not => .not,
            else => error.NotUnaryOp,
        };
    }
};

const BasicLitKind = enum {
    float,
    string,
    int,

    fn fromToken(token: lexer.Token) errors.ParseError!BasicLitKind {
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

const Clause = struct { cond: *Expr, body: *Expr };
const Field = struct { name: []const u8, type: *Expr };

const Expr = union(enum) {
    seq: struct { a: *Expr, b: *Expr },
    name: struct { text: []const u8 },
    basic_lit: struct { kind: BasicLitKind, text: []const u8 },
    bin_op: struct {
        op: BinOpKind,
        lhs: *Expr,
        rhs: *Expr,
    },
    uni_op: struct {
        op: UniOpKind,
        operand: *Expr,
    },
    if_expr: struct {
        head: Clause,
        elseifs: []const Clause,
        else_body: ?*Expr,
    },
    struct_expr: struct {
        name: []const u8,
        fields: []const Field,
    },
    proc: struct {
        name: []const u8,
        fields: []const Field,
        type: ?*Expr,
        content: *Expr,
    },
    extend: struct {
        struct_name: []const u8,
        interface_name: ?[]const u8,
        methods: []const *Expr,
    },
    // types
    array_type: struct { type: *Expr },
    set_type: struct { type: *Expr },
};

// Helper structs

const FieldSep = enum { colon, none };

// Pratt parsing algo

const State = enum {
    prefix,
    loop,
    bin_op,
    post_uni_op,
};

// returns an expression tree, free whatever alloc uses, for example with arena
pub fn parse(alloc: std.mem.Allocator, code: [:0]const u8) errors.ParseError!Expr {
    var lex = lexer.Lexer.init(code);
    return try exprBp(alloc, &lex, 0);
}

fn exprBp(alloc: std.mem.Allocator, lex: *lexer.Lexer, min_bp: u8) errors.ParseError!Expr {
    var lhs: Expr = undefined;

    state: switch (State.prefix) {
        .prefix => {
            const token = lex.next();
            lhs = try switch (token.type) {
                .identifier => Expr{ .name = .{ .text = token.text } },
                .number => Expr{ .basic_lit = .{ .kind = try BasicLitKind.fromToken(token), .text = token.text } },
                .minus => blk: {
                    const bp = try prefixBp(token.type);
                    const rhs = try alloc.create(Expr);
                    rhs.* = try exprBp(alloc, lex, bp.r);
                    break :blk Expr{ .uni_op = .{ .op = try UniOpKind.fromToken(token.type), .operand = rhs } };
                },
                .left_paren => blk: {
                    const rhs = try exprBp(alloc, lex, 0);
                    const t = lex.next();
                    if (t.type != .right_paren) return error.ExpectedRParen;
                    break :blk rhs;
                },
                .keyword_if => try parseIf(alloc, lex),
                .keyword_struct => try parseStruct(alloc, lex),
                .keyword_extend => try parseExtend(alloc, lex),
                else => error.UnexpectedToken,
            };
            continue :state .loop;
        },
        .loop => {
            switch (lex.peek().type) {
                .eof, .right_paren, .right_brace => return lhs,
                .minus, .plus, .mult => continue :state .bin_op,
                .not => continue :state .post_uni_op,
                else => return error.NotImplemented,
            }
        },
        .bin_op => {
            const peek = lex.peek();
            const op = try BinOpKind.fromToken(peek.type);
            const bp = try infixBp(peek.type);
            if (bp.l < min_bp) return lhs;

            _ = lex.next();
            const rhs_node = try alloc.create(Expr);
            rhs_node.* = try exprBp(alloc, lex, bp.r);
            const lhs_node = try alloc.create(Expr);
            lhs_node.* = lhs;
            lhs = .{ .bin_op = .{ .op = op, .lhs = lhs_node, .rhs = rhs_node } };
            continue :state .loop;
        },
        .post_uni_op => {
            const peek = lex.peek();
            const op = try UniOpKind.fromToken(peek.type);
            const bp = try postfixBp(peek.type);
            if (bp.l < min_bp) return lhs;

            _ = lex.next();
            const lhs_node = try alloc.create(Expr);
            lhs_node.* = lhs;
            lhs = .{ .uni_op = .{ .op = op, .operand = lhs_node } };
            continue :state .loop;
        },
    }
}

// Binding power

const Bp = struct { l: u8, r: u8 };

fn postfixBp(op: lexer.TokenType) errors.ParseError!Bp {
    return switch (op) {
        .not => Bp{ .l = 6, .r = undefined },
        else => error.UnexpectedToken,
    };
}

fn prefixBp(op: lexer.TokenType) errors.ParseError!Bp {
    return switch (op) {
        .minus => Bp{ .l = undefined, .r = 5 },
        else => error.UnexpectedToken,
    };
}

fn infixBp(op: lexer.TokenType) errors.ParseError!Bp {
    return switch (op) {
        .minus, .plus => Bp{ .l = 1, .r = 2 },
        .mult => Bp{ .l = 3, .r = 4 },
        else => error.UnexpectedToken,
    };
}

// Parse expressions

fn parseExtend(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const struct_name = lex.next();
    if (struct_name.type != .identifier) return error.ExpectedIdentifier;

    // for now the structs can't be used with interfaces
    // if (lex.next().type != .keyword_with) return error.ExpectedWith;
    //
    // const interface_name = lex.next();
    // if (interface_name.type != .identifier) return error.ExpectedIdentifier;

    if (lex.next().type != .left_brace) return error.ExpectedLBrace;

    const methods: std.ArrayList(*Expr) = .empty;

    while (lex.peek().type != .right_brace) {
        const tk = lex.next();
        const method = try alloc.create(Expr);

        method.* = switch (tk.type) {
            .keyword_proc => try parseProc(alloc, lex),
            else => return error.ExpectedProcOrUpon,
        };

        try methods.append(alloc, lex);
    }

    _ = lex.next();

    const extend_node = try alloc.create(Expr);
    extend_node.* = Expr{ .extend = .{
        .interface_name = null,
        .struct_name = struct_name.text,
        .methods = try methods.toOwnedSlice(alloc),
    } };
    const rest = try alloc.create(Expr);
    rest.* = try exprBp(alloc, lex, 0);

    return Expr{ .seq = .{ .a = extend_node, .b = rest } };
}

fn parseFields(alloc: std.mem.Allocator, lex: *lexer.Lexer, brk: lexer.TokenType, sep: FieldSep) errors.ParseError![]Field {
    var fields: std.ArrayList(Field) = .empty;
    defer fields.deinit(alloc);

    while (lex.peek().type != brk) {
        const field_name = lex.next();
        if (field_name.type != .identifier) return error.ExpectedIdentifier;

        if (sep == .colon) {
            if (lex.next().type != .colon) return error.ExpectedColon;
        }

        const tp = try alloc.create(Expr);
        tp.* = try parseType(alloc, lex);

        const tk = lex.peek();
        if (tk.type != .comma and tk.type != brk) {
            return error.ExpectedComma;
        }
        if (tk.type == .comma) _ = lex.next();

        try fields.append(alloc, Field{ .name = field_name.text, .type = tp });
    }

    _ = lex.next();

    return fields.toOwnedSlice(alloc);
}

fn parseProc(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const name = lex.next();
    if (name.type != .identifier) return error.ExpectedIdentifier;
    if (lex.next().type != .left_paren) return error.ExpectedLParen;

    const fields = try parseFields(alloc, lex, .right_paren, .none);

    var tp = null;
    if (lex.peek().type != .left_brace) tp = try parseType(alloc, lex);

    if (lex.next().type != .left_brace) return error.ExpectedLBrace;

    const content = alloc.create(Expr);
    content.* = exprBp(alloc, lex, 0);

    if (lex.next().type != .right_brace) return error.ExpectedRBrace;

    return Expr{
        .proc = .{
            .name = name.text,
            .fields = fields,
            .type = tp,
            .content = content,
        },
    };
}

fn parseStruct(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const name = lex.next();
    if (name.type != .identifier) return error.ExpectedIdentifier;

    if (lex.next().type != .left_brace) return error.ExpectedLBrace;

    const fields = try parseFields(alloc, lex, .right_brace, .colon);
    if (fields.len == 0) return error.ExtendEmpty;

    const struct_node = try alloc.create(Expr);
    struct_node.* = Expr{ .struct_expr = .{ .name = name.text, .fields = fields } };
    const rest = try alloc.create(Expr);
    rest.* = try exprBp(alloc, lex, 0);

    return Expr{ .seq = .{ .a = struct_node, .b = rest } };
}

fn parseType(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const token = lex.next();
    return switch (token.type) {
        .identifier => Expr{ .name = .{ .text = token.text } },
        .left_square => blk: {
            if (.right_square != lex.next().type) return error.ExpectedRSquare;
            const tp = try alloc.create(Expr);
            tp.* = try parseType(alloc, lex);

            break :blk Expr{ .array_type = .{ .type = tp } };
        },
        .keyword_set => blk: {
            if (.left_square != lex.next().type) return error.ExpectedLSquare;
            const tp = try alloc.create(Expr);
            tp.* = try parseType(alloc, lex);

            if (.right_square != lex.next().type) return error.ExpectedRSquare;

            break :blk Expr{ .set_type = .{ .type = tp } };
        },
        else => error.UnexpectedToken,
    };
}

fn parseIf(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const first_if = try parseIfCondBody(alloc, lex);

    var elseifs: std.ArrayList(Clause) = .empty;
    defer elseifs.deinit(alloc);

    while (.keyword_elif == lex.peek().type) {
        _ = lex.next();
        const elseif = try parseIfCondBody(alloc, lex);
        try elseifs.append(alloc, elseif);
    }

    var body: ?*Expr = null;
    if (.keyword_else == lex.peek().type) {
        _ = lex.next();
        body = try parseBody(alloc, lex);
    }

    const if_expr = try alloc.create(Expr);
    if_expr.* = Expr{
        .if_expr = .{
            .head = first_if,
            .elseifs = try elseifs.toOwnedSlice(alloc),
            .else_body = body,
        },
    };
    const rest = try alloc.create(Expr);
    rest.* = try exprBp(alloc, lex, 0);

    return Expr{ .seq = .{ .a = if_expr, .b = rest } };
}

fn parseIfCondBody(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Clause {
    var t = lex.next();
    if (t.type != .left_paren) return error.ExpectedRParen;
    const cond = try alloc.create(Expr);
    cond.* = try exprBp(alloc, lex, 0);
    t = lex.next();
    if (t.type != .right_paren) return error.ExpectedLParen;

    const body = try parseBody(alloc, lex);

    return Clause{ .cond = cond, .body = body };
}

fn parseBody(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!*Expr {
    var t = lex.next();
    if (t.type != .left_brace) return error.ExpectedLBrace;
    const body = try alloc.create(Expr);
    body.* = try exprBp(alloc, lex, 0);
    t = lex.next();
    if (t.type != .right_brace) return error.ExpectedRBrace;

    return body;
}

// Tests

const testing = std.testing;

test "parse: single integer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "42");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.int, result.basic_lit.kind);
    try testing.expectEqualStrings("42", result.basic_lit.text);
}

test "parse: single float" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "3.14");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.float, result.basic_lit.kind);
    try testing.expectEqualStrings("3.14", result.basic_lit.text);
}

test "parse: addition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.op);
    try testing.expectEqualStrings("1", result.bin_op.lhs.basic_lit.text);
    try testing.expectEqualStrings("2", result.bin_op.rhs.basic_lit.text);
}

test "parse: subtraction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "5 - 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.minus, result.bin_op.op);
}

test "parse: multiplication" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "2 * 4");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op.op);
}

test "parse: mult binds tighter than plus" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2 * 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.op);
    try testing.expect(result.bin_op.rhs.* == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op.rhs.bin_op.op);
}

test "parse: plus is left-associative" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2 + 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.op);
    try testing.expect(result.bin_op.lhs.* == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.lhs.bin_op.op);
}

test "parse: parenthesized expression" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "(42)");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.int, result.basic_lit.kind);
    try testing.expectEqualStrings("42", result.basic_lit.text);
}

test "parse: parens override precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    // (1 + 2) * 3 should parse as (* (+ 1 2) 3), not (+ 1 (* 2 3))
    const result = try parse(arena.allocator(), "(1 + 2) * 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op.op);
    try testing.expect(result.bin_op.lhs.* == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.lhs.bin_op.op);
    try testing.expectEqualStrings("1", result.bin_op.lhs.bin_op.lhs.basic_lit.text);
    try testing.expectEqualStrings("2", result.bin_op.lhs.bin_op.rhs.basic_lit.text);
    try testing.expectEqualStrings("3", result.bin_op.rhs.basic_lit.text);
}

test "parse: simple if" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "if(1){2}3");
    try testing.expect(result == .seq);
    try testing.expect(result.seq.a.* == .if_expr);
    const if_expr = result.seq.a.if_expr;
    try testing.expectEqualStrings("1", if_expr.head.cond.basic_lit.text);
    try testing.expectEqualStrings("2", if_expr.head.body.basic_lit.text);
    try testing.expectEqual(@as(usize, 0), if_expr.elseifs.len);
    try testing.expectEqual(@as(?*Expr, null), if_expr.else_body);
    try testing.expectEqualStrings("3", result.seq.b.basic_lit.text);
}

test "parse: if elif else" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "if(1){2}elif(3){4}else{5}6");
    try testing.expect(result == .seq);
    const if_expr = result.seq.a.if_expr;
    try testing.expectEqualStrings("1", if_expr.head.cond.basic_lit.text);
    try testing.expectEqualStrings("2", if_expr.head.body.basic_lit.text);
    try testing.expectEqual(@as(usize, 1), if_expr.elseifs.len);
    try testing.expectEqualStrings("3", if_expr.elseifs[0].cond.basic_lit.text);
    try testing.expectEqualStrings("4", if_expr.elseifs[0].body.basic_lit.text);
    try testing.expect(if_expr.else_body != null);
    try testing.expectEqualStrings("5", if_expr.else_body.?.basic_lit.text);
    try testing.expectEqualStrings("6", result.seq.b.basic_lit.text);
}

test "parse struct: one field array type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: []int}1");
    try testing.expect(result == .seq);
    const se = result.seq.a.struct_expr;
    try testing.expectEqualStrings("Foo", se.name);
    try testing.expectEqual(@as(usize, 1), se.fields.len);
    try testing.expectEqualStrings("foo1", se.fields[0].name);
    try testing.expect(se.fields[0].type.* == .array_type);
    try testing.expectEqualStrings("int", se.fields[0].type.array_type.type.name.text);
}

test "parse struct: one field set type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: set[int]}1");
    try testing.expect(result == .seq);
    const se = result.seq.a.struct_expr;
    try testing.expectEqual(@as(usize, 1), se.fields.len);
    try testing.expectEqualStrings("foo1", se.fields[0].name);
    try testing.expect(se.fields[0].type.* == .set_type);
    try testing.expectEqualStrings("int", se.fields[0].type.set_type.type.name.text);
}

test "parse struct: set of array type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: set[[]op]}1");
    try testing.expect(result == .seq);
    const field = result.seq.a.struct_expr.fields[0];
    try testing.expectEqualStrings("foo1", field.name);
    try testing.expect(field.type.* == .set_type);
    try testing.expect(field.type.set_type.type.* == .array_type);
    try testing.expectEqualStrings("op", field.type.set_type.type.array_type.type.name.text);
}

test "parse struct: array of array type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {grid: [][]int}1");
    try testing.expect(result == .seq);
    const field = result.seq.a.struct_expr.fields[0];
    try testing.expect(field.type.* == .array_type);
    try testing.expect(field.type.array_type.type.* == .array_type);
    try testing.expectEqualStrings("int", field.type.array_type.type.array_type.type.name.text);
}

test "parse struct: set of set type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {nested: set[set[int]]}1");
    try testing.expect(result == .seq);
    const field = result.seq.a.struct_expr.fields[0];
    try testing.expect(field.type.* == .set_type);
    try testing.expect(field.type.set_type.type.* == .set_type);
    try testing.expectEqualStrings("int", field.type.set_type.type.set_type.type.name.text);
}

test "parse struct: two fields with trailing comma" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: set[[]op], foo2: string,}1");
    try testing.expect(result == .seq);
    const se = result.seq.a.struct_expr;
    try testing.expectEqualStrings("Foo", se.name);
    try testing.expectEqual(@as(usize, 2), se.fields.len);
    try testing.expectEqualStrings("foo1", se.fields[0].name);
    try testing.expect(se.fields[0].type.* == .set_type);
    try testing.expectEqualStrings("foo2", se.fields[1].name);
    try testing.expect(se.fields[1].type.* == .name);
    try testing.expectEqualStrings("string", se.fields[1].type.name.text);
}

test "parse struct: two fields without trailing comma" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: set[[]op], foo2: string}1");
    try testing.expect(result == .seq);
    const se = result.seq.a.struct_expr;
    try testing.expectEqual(@as(usize, 2), se.fields.len);
    try testing.expectEqualStrings("foo1", se.fields[0].name);
    try testing.expectEqualStrings("foo2", se.fields[1].name);
}

test "parse struct: empty struct" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try testing.expectError(error.ExtendEmpty, parse(arena.allocator(), "struct Empty {}1"));
}

test "parse: postfix ! binds tighter than +" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    // 2 + 3! should parse as 2 + (3!), not (2 + 3)!
    const result = try parse(arena.allocator(), "2 + 3!");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.op);
    try testing.expectEqualStrings("2", result.bin_op.lhs.basic_lit.text);
    try testing.expect(result.bin_op.rhs.* == .uni_op);
    try testing.expectEqual(UniOpKind.not, result.bin_op.rhs.uni_op.op);
    try testing.expectEqualStrings("3", result.bin_op.rhs.uni_op.operand.basic_lit.text);
}
