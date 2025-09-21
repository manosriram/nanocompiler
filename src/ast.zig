const std = @import("std");
const Token = @import("tokenize.zig").Token;
const TokenType = @import("tokenize.zig").TokenType;
const utils = @import("utils.zig");
const types = @import("types.zig");

pub const Ast = struct {
    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,
    current_token_index: usize,
    nodes: std.ArrayList(*types.Node),
    symbol_table: std.StringHashMap(*types.Node),
    name_index: f64,
    three_address_nodes: std.ArrayList(types.ThreeAddressNode()),
    current_var: []const u8,
    prev_var: []const u8,
    prev_prev_var: []const u8,

    fn is_at_end(self: *Ast) bool {
        return self.current_token_index >= self.tokens.items.len;
    }

    fn eat(self: *Ast) bool {
        if (!self.is_at_end()) {
            self.current_token_index += 1;
            return true;
        }

        return false;
    }

    fn concatAllocated(self: *Ast, a: []const u8, b: []const u8) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ a, b });
    }

    fn concatToBuffer(buffer: []u8, a: []const u8, b: []const u8) []u8 {
        @memcpy(buffer[0..a.len], a);
        @memcpy(buffer[a.len .. a.len + b.len], b);
        return buffer[0 .. a.len + b.len];
    }

    fn get_current_token(self: *Ast) Token {
        if (self.is_at_end()) return undefined;
        return self.tokens.items[self.current_token_index];
    }

    fn name_generator(self: *Ast) ![]const u8 {
        const prefix = "t";
        const name = try utils.usizeToStr(self.name_index);
        self.name_index += 1;

        return try self.concatAllocated(prefix, name);
    }

    fn _generate_result_for_binary_node(self: *Ast, left: types.Result, right: types.Result, op: TokenType) !types.Result {
        self.current_var = try self.concatAllocated(try self.name_generator(), "");
        var formatted_string: []u8 = "";

        switch (left) {
            .str => {
                switch (right) {
                    .str => {
                        formatted_string = try std.fmt.allocPrint(self.allocator, "{s} = {s} {s} {s}", .{ self.current_var, left.str, op.to_string(), right.str });
                    },
                    .num => {
                        formatted_string = try std.fmt.allocPrint(self.allocator, "{s} = {s} {s} {d}", .{ self.current_var, left.str, op.to_string(), right.num });
                    },
                }
            },
            .num => {
                switch (right) {
                    .str => {
                        formatted_string = try std.fmt.allocPrint(self.allocator, "{s} = {d} {s} {s}", .{ self.current_var, left.num, op.to_string(), right.str });
                    },
                    .num => {
                        formatted_string = try std.fmt.allocPrint(self.allocator, "{s} = {d} {s} {d}", .{ self.current_var, left.num, op.to_string(), right.num });
                    },
                }
            },
        }

        try self.three_address_nodes.append(.{ .operator = op.to_string(), .result = formatted_string, .var_name = self.current_var });

        return types.Result{ .str = self.current_var };
    }

    // Generates 3 address code from a given AST
    // https://en.wikipedia.org/wiki/Three-address_code
    fn generate_3_address_code_from_ast(self: *Ast, node: *types.Node, i: i32) !types.Result {
        switch (node.*) {
            .binary_op => {
                const left = try self.generate_3_address_code_from_ast(node.binary_op.left, i + 1); // "1"
                const right = try self.generate_3_address_code_from_ast(node.binary_op.right, i + 1); // "2"

                switch (node.binary_op.op) {
                    .multiply => {
                        return try self._generate_result_for_binary_node(left, right, TokenType.multiply);
                    },
                    .plus => {
                        return try self._generate_result_for_binary_node(left, right, TokenType.plus);
                    },
                    .minus => {
                        return try self._generate_result_for_binary_node(left, right, TokenType.minus);
                    },
                    .divide => {
                        return try self._generate_result_for_binary_node(left, right, TokenType.divide);
                    },
                    else => {
                        return undefined;
                    },
                }
                return 0;
            },
            .unary_op => {
                const right = try self.generate_3_address_code_from_ast(node.unary_op.operand, i + 1); // "2"
                self.current_var = try self.concatAllocated(try self.name_generator(), "");
                var formatted_string: []u8 = "";
                switch (right) {
                    .str => {
                        formatted_string = try std.fmt.allocPrint(self.allocator, "{s} = {s}{s}", .{ self.current_var, node.unary_op.op.to_string(), right.str });
                    },
                    .num => {
                        formatted_string = try std.fmt.allocPrint(self.allocator, "{s} = {s}{d}", .{ self.current_var, node.unary_op.op.to_string(), right.num });
                    },
                }

                try self.three_address_nodes.append(.{ .operator = node.unary_op.op.to_string(), .result = formatted_string, .var_name = self.current_var });

                return types.Result{ .str = self.current_var };
            },
            .number => {
                return types.Result{ .num = node.number };
            },
            .ident => {
                return undefined;
            },
        }
        return types.Result{ .num = node.number };
    }

    fn print_node(self: *Ast, node: *types.Node) f64 { // use LiteralNode?
        switch (node.*) {
            .binary_op => {
                const left = self.print_node(node.binary_op.left);
                const right = self.print_node(node.binary_op.right);

                switch (node.binary_op.op) {
                    .multiply => {
                        // std.debug.print("{d} * {d}\n", .{left, right});
                        return left * right;
                    },
                    .plus => {
                        // std.debug.print("{d} + {d}\n", .{left, right});
                        return left + right;
                    },
                    .minus => {
                        // std.debug.print("{d} - {d}\n", .{left, right});
                        return left - right;
                    },
                    .divide => {
                        // std.debug.print("{d} / {d}\n", .{left, right});
                        return left / right;
                    },
                    else => {
                        return 0;
                    },
                }
                return undefined;
            },
            .unary_op => {
                const value = self.print_node(node.unary_op.operand);
                switch (node.unary_op.op) {
                    .minus => {
                        return -value;
                    },
                    .plus => {
                        return value;
                    },
                    else => {},
                }
                return undefined;
            },
            .number => {
                return node.number;
            },
            .ident => {
                return undefined;
                // if (self.symbol_table.get(node.ident)) |val| {
                // std.debug.print("value of {s} is {}\n", .{node.ident, val.number});
                // } else {
                // std.debug.print("Unknown symbol {s}", .{node.ident});
                // }
            },
        }
    }

    pub fn print(self: *Ast) !void {
        for (self.nodes.items) |node| {
            _ = try self.generate_3_address_code_from_ast(node, 0);
        }
    }

    pub fn destroy(self: *Ast) void {
        for (self.nodes.items) |node| {
            self.destroy_node(node);
        }

        var it = self.symbol_table.valueIterator();
        while (it.next()) |node| {
            self.allocator.destroy(node.*);
        }
    }

    // TODO: Tokenization from source is hardcoded here for now
    // Update this to actually tokenize from source and then remove these
    // hardcoded values
    pub fn init(self: *Ast) !void {
        self.tokens = std.ArrayList(Token).init(self.allocator);
        self.nodes = std.ArrayList(*types.Node).init(self.allocator);
        self.three_address_nodes = std.ArrayList(types.ThreeAddressNode()).init(self.allocator);
        self.symbol_table = std.StringHashMap(*types.Node).init(self.allocator);

        try self.tokens.appendSlice(&[_]Token{
            // Test case 1: Simple addition - 1 + 2
            // Token{.line = 0, .type = TokenType.minus, .lexeme = "-"},
            Token{ .line = 0, .type = TokenType.literal, .lexeme = "1" },
            Token{ .line = 0, .type = TokenType.plus, .lexeme = "+" },
            Token{ .line = 0, .type = TokenType.literal, .lexeme = "2" },
            // Token{.line = 0, .type = TokenType.minus, .lexeme = "-"},
            // Token{.line = 0, .type = TokenType.literal, .lexeme = "3"},
            // Token{.line = 0, .type = TokenType.multiply, .lexeme = "*"},
            // Token{.line = 0, .type = TokenType.literal, .lexeme = "4"},
            // Token{.line = 0, .type = TokenType.multiply , .lexeme = "*"},
            // Token{.line = 0, .type = TokenType.literal, .lexeme = "5"},
            // Token{.line = 0, .type = TokenType.multiply, .lexeme = "*"},
            // Token{.line = 0, .type = TokenType.literal, .lexeme = "3"},

            // // Test case 2: Operator precedence - 2 + 3 * 4
            // Token{.line = 1, .type = TokenType.literal, .lexeme = "2"},
            // Token{.line = 1, .type = TokenType.plus, .lexeme = "+"},
            // Token{.line = 1, .type = TokenType.literal, .lexeme = "3"},
            // Token{.line = 1, .type = TokenType.multiply, .lexeme = "*"},
            // Token{.line = 1, .type = TokenType.literal, .lexeme = "4"},

            // Test case 3: Parentheses - (1 + 2) * 3
            // Token{.line = 2, .type = TokenType.open_parantheses, .lexeme = "("},
            // Token{.line = 2, .type = TokenType.literal, .lexeme = "1"},
            // Token{.line = 2, .type = TokenType.plus, .lexeme = "+"},
            // Token{.line = 2, .type = TokenType.literal, .lexeme = "2"},
            // Token{.line = 2, .type = TokenType.close_paranthesis, .lexeme = ")"},
            // Token{.line = 2, .type = TokenType.multiply, .lexeme = "*"},
            // Token{.line = 2, .type = TokenType.literal, .lexeme = "3"},
            // Token{.line = 2, .type = TokenType.semicolon, .lexeme = ";"},

            // // Test case 4: Unary operators - -5 + 10
            // Token{.line = 3, .type = TokenType.minus, .lexeme = "-"},
            // Token{.line = 3, .type = TokenType.literal, .lexeme = "5"},
            // Token{.line = 3, .type = TokenType.plus, .lexeme = "+"},
            // Token{.line = 3, .type = TokenType.literal, .lexeme = "10"},
            // Token{.line = 2, .type = TokenType.semicolon, .lexeme = ";"},

            // // // Test case 5: Division - 20 / 4 - 2
            // Token{.line = 4, .type = TokenType.literal, .lexeme = "20"},
            // Token{.line = 4, .type = TokenType.divide, .lexeme = "/"},
            // Token{.line = 4, .type = TokenType.literal, .lexeme = "4"},
            // Token{.line = 4, .type = TokenType.minus, .lexeme = "-"},
            // Token{.line = 4, .type = TokenType.literal, .lexeme = "2"},
            // Token{.line = 2, .type = TokenType.semicolon, .lexeme = ";"},

            // // // Test case 6: Complex nested parentheses - ((1 + 2) * (3 - 1))
            // Token{.line = 5, .type = TokenType.open_parantheses, .lexeme = "("},
            // Token{.line = 5, .type = TokenType.open_parantheses, .lexeme = "("},
            // Token{.line = 5, .type = TokenType.literal, .lexeme = "1"},
            // Token{.line = 5, .type = TokenType.plus, .lexeme = "+"},
            // Token{.line = 5, .type = TokenType.literal, .lexeme = "2"},
            // Token{.line = 5, .type = TokenType.close_paranthesis, .lexeme = ")"},
            // Token{.line = 5, .type = TokenType.multiply, .lexeme = "*"},
            // Token{.line = 5, .type = TokenType.open_parantheses, .lexeme = "("},
            // Token{.line = 5, .type = TokenType.literal, .lexeme = "3"},
            // Token{.line = 5, .type = TokenType.minus, .lexeme = "-"},
            // Token{.line = 5, .type = TokenType.literal, .lexeme = "1"},
            // Token{.line = 5, .type = TokenType.close_paranthesis, .lexeme = ")"},
            // Token{.line = 5, .type = TokenType.close_paranthesis, .lexeme = ")"},
            // Token{.line = 2, .type = TokenType.semicolon, .lexeme = ";"},

            // // Test case 7: Variable assignment - x = 42
            // Token{.line = 6, .type = TokenType.ident, .lexeme = "x"},
            // Token{.line = 6, .type = TokenType.equal, .lexeme = "="},
            // Token{.line = 6, .type = TokenType.literal, .lexeme = "42"},

            // Test case 8: Multiple unary operators - --5
            // Token{.line = 7, .type = TokenType.minus, .value = "-"},
            // Token{.line = 7, .type = TokenType.minus, .value = "-"},
            // Token{.line = 7, .type = TokenType.literal, .value = "5"},
        });
    }

    pub fn deinit(self: *Ast) void {
        defer _ = self.tokens.deinit();
        defer _ = self.nodes.deinit();
        defer _ = self.symbol_table.deinit();

        defer self.destroy();
        for (self.three_address_nodes.items) |node| {
            self.allocator.free(node.var_name);
            self.allocator.free(node.result);
        }
        defer _ = self.three_address_nodes.deinit();
    }

    pub fn destroy_node(self: *Ast, node: *types.Node) void {
        switch (node.*) {
            .number, .ident => {
                self.allocator.destroy(node);
            },
            .binary_op => |*op| {
                self.destroy_node(op.left);
                self.destroy_node(op.right);
                self.allocator.destroy(node);
            },
            .unary_op => |*op| {
                self.destroy_node(op.operand);
                self.allocator.destroy(node);
            },
        }
    }

    pub fn Parse(self: *Ast) types.ParseError!void {
        while (!self.is_at_end()) {
            try self.nodes.append(try self.expr());
            _ = self.eat();
        }

        std.debug.print("size = {d}\n", .{self.nodes.items.len});
    }

    fn expr(self: *Ast) types.ParseError!*types.Node {
        var left = try self.term();

        while (self.get_current_token().type != TokenType.semicolon) {
            const current = self.get_current_token(); // +
            switch (current.type) {
                .plus, .minus => {
                    const ok = self.eat();
                    if (!ok) return left;

                    const right = try self.term(); // 23
                    const node = try self.allocator.create(types.Node);
                    node.* = types.Node{ .binary_op = types.Node.BinOp{
                        .left = left,
                        .right = right,
                        .op = current.type,
                    } };
                    left = node;
                },
                else => {
                    return left;
                },
            }
        }

        return left;
    }

    fn term(self: *Ast) types.ParseError!*types.Node {
        var left = try self.factor();

        while (self.get_current_token().type != TokenType.semicolon) {
            const t: Token = self.get_current_token();
            switch (t.type) {
                .multiply, .divide => {
                    const ok = self.eat();
                    if (!ok) return left;
                    const right = try self.factor();
                    const node = try self.allocator.create(types.Node);

                    node.* = types.Node{ .binary_op = types.Node.BinOp{
                        .left = left,
                        .right = right,
                        .op = t.type,
                    } };
                    left = node;
                    // return node;
                },
                // .semicolon => {
                // _ = self.eat();
                // break;
                // },
                else => {
                    return left;
                },
            }
        }
        return left;
    }

    fn factor(self: *Ast) types.ParseError!*types.Node {
        const t: Token = self.get_current_token();

        switch (t.type) {
            .literal => {
                const node = try self.allocator.create(types.Node);
                const val = try std.fmt.parseFloat(f64, t.lexeme);
                _ = self.eat();

                node.* = types.Node{
                    .number = val,
                };

                return node;
            },
            .ident => {
                const node = try self.allocator.create(types.Node);
                const name = t.lexeme;
                _ = self.eat();
                _ = self.eat();

                const right = try self.expr();

                try self.symbol_table.put(name, right);

                node.* = types.Node{
                    .ident = name,
                };

                return node;
            },
            .minus, .plus => {
                const tk = t;
                _ = self.eat();
                const right = try self.factor();

                const node = try self.allocator.create(types.Node);
                node.* = types.Node{ .unary_op = types.Node.UnaryOp{
                    .op = tk.type,
                    .operand = right,
                } };

                return node;
            },
            .open_parantheses => {
                _ = self.eat();
                const current = try self.expr();
                _ = self.eat(); // ")"
                return current;
            },
            // .semicolon => {
            // _ = self.eat();
            // return undefined;
            // },
            else => {
                return undefined;
            },
        }
    }
};
