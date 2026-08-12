const lexer = @import("lexer");
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
        switch (token) {
            .equal => return .equal,
            .greater => return .greater,
            .greater_equal => return .greater_equal,
            .less => return .less,
            .less_equal => return .less_equal,
            .minus => return .minus,
            .plus => return .plus,
            .mult => return .mult,
            else => return error.NotImplemented,
        }
    }
};

const Expr = union(enum) {
    number: f16,
    string: []const u8,
    bool: bool,
    bin_op: struct { BinOpKind, *Expr, *Expr },
};

const Bp = struct { l: u8, r: u8 };

pub fn parse(code: [:0]const u8) errors.ParseError!Expr {
    const lex = lexer.Lexer.init(code);
    return try expr_bp(&lex, 0);
}

fn expr_bp(lex: *lexer.Lexer, min_bp: u8) errors.ParseError!Expr {
    const nextToken = lex.next();
    var lhs = switch (nextToken.type) {
        .number => {
            return Expr.number;
        },
        else => {
            return error.UnexpectedToken;
        },
    };

    while (true) {
        const peek = lex.peek();
        const op = try switch (peek.type) {
            .eof => break,
            .minus, .plus, .mult => |t| {
                return BinOpKind.FromToken(t);
            },
            else => return error.NotImplemented,
        };

        const bp = try infix_bp(op);
        if (bp.l < min_bp) {
            break;
        }
        lexer.next();
        const rhs =  expr_bp(lex, bp.r);

        lhs = .{.bin_op = .{op, lhs, rhs}};
    }

    return lhs;
}

fn infix_bp(op: BinOpKind) errors.ParseError!Bp {
    switch (op) {
        .minus, .plus => Bp{ 1, 2 },
        .mult => Bp{ 3, 4 },
        else => {
            return error.NotImplemented;
        },
    }
}

// nud -> prefix handler -> called when there's no left expression yet
// lef -> infix handler -> called when there is already a left expression
