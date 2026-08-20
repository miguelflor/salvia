const std = @import("std");

const errors = @import("errors");
const lexer = @import("lexer");

// Expressions structs

pub const BinOpKind = enum {
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

pub const UniOpKind = enum {
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

pub const BasicLitKind = enum {
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

pub const Expr = union(enum) {
    seq: struct { a: *Expr, b: *Expr },
    name: []const u8,
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
    return_expr: *Expr,
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
    protocol: struct {
        name: []const u8,
        interface_name: ?[]const u8,
        fields: []const Field,
        upons: []const *Expr,
        procs: []const *Expr,
    },
    // types
    array_type: *Expr,
    set_type: *Expr,

    fn create(self: Expr, alloc: std.mem.Allocator) !*Expr {
        const expr = try alloc.create(Expr);
        expr.* = self;
        return expr;
    }
};

// Helper structs

const FieldSep = enum { colon, none };
const MethodType = union(enum) {
    upon_and_proc: struct { upon: std.ArrayList(*Expr), proc: std.ArrayList(*Expr) },
    proc: std.ArrayList(*Expr),
};

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
                .identifier => Expr{ .name = token.text },
                .number => Expr{ .basic_lit = .{ .kind = try BasicLitKind.fromToken(token), .text = token.text } },
                .minus => blk: {
                    const bp = try prefixBp(token.type);
                    const rhs = try (try exprBp(alloc, lex, bp.r)).create(alloc);
                    break :blk Expr{ .uni_op = .{ .op = try UniOpKind.fromToken(token.type), .operand = rhs } };
                },
                .left_paren => blk: {
                    const rhs = try exprBp(alloc, lex, 0);
                    const t = lex.next();
                    if (t.type != .right_paren) return error.ExpectedRParen;
                    break :blk rhs;
                },
                .keyword_if => try parseSeq(alloc, lex, try parseIf(alloc, lex)),
                .keyword_struct => try parseSeq(alloc, lex, try parseStruct(alloc, lex)),
                .keyword_extend => try parseSeq(alloc, lex, try parseExtend(alloc, lex)),
                .keyword_proc => try parseSeq(alloc, lex, try parseProc(alloc, lex)),
                .keyword_return => try parseSeq(
                    alloc,
                    lex,
                    Expr{ .return_expr = try (try exprBp(alloc, lex, 0)).create(alloc) },
                ),
                .keyword_protocol => try parseSeq(alloc, lex, try parseProtocol(alloc, lex)),
                else => error.UnexpectedToken,
            };
            continue :state .loop;
        },
        .loop => {
            switch (lex.peek().type) {
                .eof, .right_paren, .right_brace => return lhs,
                .semicolon => return try parseSeq(alloc, lex, lhs),
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
            const rhs_node = try (try exprBp(alloc, lex, bp.r)).create(alloc);
            const lhs_node = try lhs.create(alloc);
            lhs = .{ .bin_op = .{ .op = op, .lhs = lhs_node, .rhs = rhs_node } };
            continue :state .loop;
        },
        .post_uni_op => {
            const peek = lex.peek();
            const op = try UniOpKind.fromToken(peek.type);
            const bp = try postfixBp(peek.type);
            if (bp.l < min_bp) return lhs;

            _ = lex.next();
            const lhs_node = try lhs.create(alloc);
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

fn parseSeq(alloc: std.mem.Allocator, lex: *lexer.Lexer, expr: Expr) errors.ParseError!Expr {
    const expr_pt = try expr.create(alloc);
    const next_expr = try (try exprBp(alloc, lex, 0)).create(alloc);

    return Expr{ .seq = .{ .a = expr_pt, .b = next_expr } };
}

fn parseProtocol(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const proto_name = lex.next();
    if (proto_name.type != .identifier) return error.ExpectedIdentifier;

    var interface_name: ?[]const u8 = null;
    if (lex.peek().type == .keyword_impl) {
        _ = lex.next();
        const tk = lex.next();
        if (tk.type != .identifier) return error.ExpectedIdentifier;
        interface_name = tk.text;
    }

    if (lex.next().type != .left_brace) return error.ExpectedLBrace;
    const fields = try parseFields(
        alloc,
        lex,
        &.{ .right_brace, .keyword_upon, .keyword_proc },
        .colon,
    );

    var method_type: MethodType = .{ .upon_and_proc = .{ .proc = .empty, .upon = .empty } };
    defer method_type.upon_and_proc.upon.deinit(alloc);
    defer method_type.upon_and_proc.proc.deinit(alloc);
    try parseFunctions(alloc, lex, &method_type);
    _ = lex.next();

    return Expr{ .protocol = .{
        .name = proto_name.text,
        .interface_name = interface_name,
        .fields = fields,
        .upons = try method_type.upon_and_proc.upon.toOwnedSlice(alloc),
        .procs = try method_type.upon_and_proc.proc.toOwnedSlice(alloc),
    } };
}

fn parseExtend(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const struct_name = lex.next();
    if (struct_name.type != .identifier) return error.ExpectedIdentifier;

    // for now the structs can't be used with interfaces
    // if (lex.next().type != .keyword_with) return error.ExpectedWith;
    //
    // const interface_name = lex.next();
    // if (interface_name.type != .identifier) return error.ExpectedIdentifier;

    if (lex.next().type != .left_brace) return error.ExpectedLBrace;

    var method_type: MethodType = .{ .proc = .empty };
    defer method_type.proc.deinit(alloc);
    try parseFunctions(alloc, lex, &method_type);
    _ = lex.next();

    return Expr{ .extend = .{
        .interface_name = null,
        .struct_name = struct_name.text,
        .methods = try method_type.proc.toOwnedSlice(alloc),
    } };
}

// Parses a method, both proc or proc and upon. appends to the given array in method_type struct
fn parseFunctions(alloc: std.mem.Allocator, lex: *lexer.Lexer, method_type: *MethodType) errors.ParseError!void {

    std.debug.print("{any}\n", .{lex.peek()});
    while (lex.peek().type != .right_brace) {
        const tk = lex.next();
        switch (tk.type) {
            .keyword_proc => {
                const method = try (try parseProc(alloc, lex)).create(alloc);
                switch (method_type.*) {
                    .upon_and_proc => |*m| try m.proc.append(alloc, method),
                    .proc => |*m| try m.append(alloc, method),
                }
            },
            .keyword_upon => switch (method_type.*) {
                .proc => return error.OnlyProc,
                .upon_and_proc => |*m| {
                    const upon = try (try parseUpon(alloc, lex)).create(alloc);
                    try m.upon.append(alloc, upon);
                },
            },
            else => return error.ExpectedProc,
        }
    }

}

fn parseUpon(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    _ = alloc;
    _ = lex;
    unreachable;
}

fn parseFields(alloc: std.mem.Allocator, lex: *lexer.Lexer, brk: []const lexer.TokenType, sep: FieldSep) errors.ParseError![]Field {
    var fields: std.ArrayList(Field) = .empty;
    defer fields.deinit(alloc);

    while (std.mem.findScalar(lexer.TokenType, brk, lex.peek().type) == null) {
        const field_name = lex.next();
        if (field_name.type != .identifier) return error.ExpectedIdentifier;

        if (sep == .colon) {
            if (lex.next().type != .colon) return error.ExpectedColon;
        }

        const tp = try (try parseType(alloc, lex)).create(alloc);

        const tk = lex.peek();
        if (tk.type != .comma and std.mem.findScalar(lexer.TokenType, brk, tk.type) == null) {
            return error.ExpectedComma;
        }
        if (tk.type == .comma) _ = lex.next();

        try fields.append(alloc, Field{ .name = field_name.text, .type = tp });
    }


    return fields.toOwnedSlice(alloc);
}

fn parseProc(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const name = lex.next();
    if (name.type != .identifier) return error.ExpectedIdentifier;
    if (lex.next().type != .left_paren) return error.ExpectedLParen;

    const fields = try parseFields(alloc, lex, &.{.right_paren}, .none);

    var tp: ?*Expr = null;
    if (lex.peek().type != .left_brace) {
        tp = try (try parseType(alloc, lex)).create(alloc);
    }

    if (lex.next().type != .left_brace) return error.ExpectedLBrace;

    const content = try (try exprBp(alloc, lex, 0)).create(alloc);

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

    const fields = try parseFields(alloc, lex, &.{.right_brace}, .colon);
    _ = lex.next();
    if (fields.len == 0) return error.ExtendEmpty;

    return Expr{ .struct_expr = .{ .name = name.text, .fields = fields } };
}

fn parseType(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Expr {
    const token = lex.next();
    return switch (token.type) {
        .identifier => Expr{ .name = token.text },
        .left_square => blk: {
            if (.right_square != lex.next().type) return error.ExpectedRSquare;
            const tp = try (try parseType(alloc, lex)).create(alloc);
            break :blk Expr{ .array_type = tp };
        },
        .keyword_set => blk: {
            if (.left_square != lex.next().type) return error.ExpectedLSquare;
            const tp = try (try parseType(alloc, lex)).create(alloc);

            if (.right_square != lex.next().type) return error.ExpectedRSquare;

            break :blk Expr{ .set_type = tp };
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

    return Expr{
        .if_expr = .{
            .head = first_if,
            .elseifs = try elseifs.toOwnedSlice(alloc),
            .else_body = body,
        },
    };
}

fn parseIfCondBody(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!Clause {
    var t = lex.next();
    if (t.type != .left_paren) return error.ExpectedRParen;
    const cond = try (try exprBp(alloc, lex, 0)).create(alloc);
    t = lex.next();
    if (t.type != .right_paren) return error.ExpectedLParen;

    const body = try parseBody(alloc, lex);

    return Clause{ .cond = cond, .body = body };
}

fn parseBody(alloc: std.mem.Allocator, lex: *lexer.Lexer) errors.ParseError!*Expr {
    var t = lex.next();
    if (t.type != .left_brace) return error.ExpectedLBrace;
    const body = try (try exprBp(alloc, lex, 0)).create(alloc);
    t = lex.next();
    if (t.type != .right_brace) return error.ExpectedRBrace;

    return body;
}

// Tests
test {
    _ = @import("test.zig");
}
