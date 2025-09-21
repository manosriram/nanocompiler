const std = @import("std");
const Token = @import("tokenize.zig").Token;
const TokenType = @import("tokenize.zig").TokenType;

pub const ParseError = error{
    UnexpectedToken,
    ExpectedClosingParen,
    OutOfMemory,
    InvalidCharacter,
};


pub const NodeType = enum {
    number,
    ident,
    binary_op,
    unary_op,
};


pub const Node = union(NodeType) {
    number: f64,
    ident: []const u8,
    binary_op: BinOp,
    unary_op: UnaryOp,

    pub const BinOp = struct {
        left: *Node,
        op: TokenType,
        right: *Node,
    };

    pub const UnaryOp = struct {
        operand: *Node,
        op: TokenType,
    };
};

pub const Result = union(enum) {
    str: []const u8,
    num: f64,
};

pub fn ThreeAddressNode() type {
    return struct {
        operator: []const u8,
        result: []const u8,
        var_name: []const u8,

        const Self = @This();

        pub fn init(operator: []const u8, result: []const u8) Self {
            return .{ .operator = operator, .result = result };
        }

        pub fn getOperator(self: Self) []const u8 {
            return self.operator;
        }

        pub fn getResult(self: Self) []const u8 {
            return self.result;
        }
    };
}

