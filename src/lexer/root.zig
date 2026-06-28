const std = @import("std");

const State = enum {
    start,
    identifier,
    less,
    greater,
    equal,
};

const TokenType = enum {
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
    keyword_print,
    keyword_return,
    keyword_super,
    keyword_this,
    keyword_true,
    keyword_var,
    keyword_while,

    eof,
};

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
                switch (self.pos) {
                    ' ', '\n', '\t' => {
                        self.pos += 1;
                        continue :state .start;
                    },
                    'a'...'z', 'A'...'Z' => {
                        self.pos += 1;
                        token.type = .identifier;
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
                }
            },
            .equal => {
                switch (self.pos) {
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
                switch (self.pos) {
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
                switch (self.pos) {
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
                switch (self.pos) {
                    'a'...'z','A'...'Z' => {
                        self.pos+=1;
                        continue :state .identifier;
                    },
                    else => {
                        self.pos+=1;
                    }
                }
            }

        }
    }
};
