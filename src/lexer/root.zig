const std = @import("std");

const State = enum {
    start,
    identifier,
    less,
    greater,
    string,
    equal,
};

const TokenType = enum {
    invalid,
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

const keywordStr = [_]struct { w_str: []const u8, type: TokenType }{
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
};

fn getKeywordToken(keyword: []const u8) !TokenType {
    for (keywordStr) |key_str| {
        if (std.mem.eql(u8, key_str.w_str, keyword)) {
            return key_str.type;
        }
    }
    return error.KeywordNotFound;
}

const Token = struct {
    start: usize,
    end: usize,
    type: TokenType,
};

const Scanner = struct {
    code: []const u8,
    pos: usize,

    pub fn init(code: []const u8) Scanner {
        return Scanner{
            .code = code,
            .pos = 0,
        };
    }

    pub fn next(self: Scanner) Token {
        var token = Token{
            .start = self.pos,
            .end = undefined,
            .type = undefined,
        };
        state: switch (State.start) {
            .start => {
                switch (self.code[ self.pos ]) {
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
                        continue :state .start;
                    },
                    'a'...'z', 'A'...'Z' => {
                        self.pos += 1;
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
                        self.pos+=1;
                        token.type = .string_literal;
                        continue :state .string;

                    }
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
                        token.type = getKeywordToken(self.code[token.start..self.pos]) catch .identifier;
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
                        self.pos+=1;
                        token.type = .string_literal;
                    }

                }
            }
        }
    }
};
