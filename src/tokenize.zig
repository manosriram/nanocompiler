const std = @import("std");

pub const TokenType = enum {
    plus,
    minus,
    multiply,
    divide,
    equal,
    bang_equal,
    let,
    not,
    ident,
    literal,
    open_parantheses,
    close_paranthesis,
    semicolon,

    pub fn to_string(self: TokenType) []const u8 {
        return switch (self) {
            .plus => "+",
            .minus => "-",
            .multiply => "*",
            .divide => "/",
            .equal => "=",
            .bang_equal => "!=",
            .let => "",
            .not => "!",
            .ident => "",
            .literal => "",
            .open_parantheses => "(",
            .close_paranthesis => ")",
            .semicolon => ";",
        };
    }
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: i8,
};

pub const Tokenize = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,

    pub fn init(self: *Tokenize) void {
        self.tokens = std.ArrayList(Token).init(self.allocator);
    }

    pub fn deinit(self: *Tokenize) !void {
        defer _ = self.tokens.deinit();
    }

    pub fn tokenize(_: *Tokenize) void {}
};
