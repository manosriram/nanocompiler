const std = @import("std");
const types = @import("types.zig");

pub const Generator = struct {
    allocator: std.mem.Allocator,
    three_address_nodes: std.ArrayList(types.ThreeAddressNode()), // Do we need this?

    pub fn init(_: *Generator) void {}

    fn parse_single_instruction(_: *Generator, instruction: []const u8) void {
        std.debug.print("{s}\n", .{instruction});
    }

    pub fn generate(self: *Generator) void {
        for (self.three_address_nodes.items) |x| {
            self.parse_single_instruction(x.result);
        }
    }
};
