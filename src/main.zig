const std = @import("std");
const ast = @import("ast.zig");
const generator = @import("generator.zig");

const FILE_NAME = "source";

const Token = struct { value: []const u8 };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const contents = try std.fs.cwd().readFileAlloc(allocator, FILE_NAME, 1024 * 1024);
    defer allocator.free(contents);

    // // Tokenization
    var tokens = std.ArrayList(Token).init(allocator);
    defer tokens.deinit();

    var a = ast.Ast{
        .tokens = undefined,
        .nodes = undefined,
        .symbol_table = undefined,
        .three_address_nodes = undefined,
        .allocator = allocator,
        .current_token_index = 0,
        .current_var = "",
        .prev_var = "",
        .prev_prev_var = "",
        .name_index = 0,
    };
    try a.init();
    defer a.deinit();
    _ = try a.Parse();

    try a.print();

    const file = try std.fs.cwd().createFile("out.3ac", .{});
    defer file.close();
    const writer = file.writer();

    try writer.print("// Do not edit. Auto generated 3 address code of the source\n", .{});
    for (a.three_address_nodes.items) |x| {
        try writer.print("{s}\n", .{x.result});
    }

    var g = generator.Generator{
        .allocator = allocator,
        .three_address_nodes = a.three_address_nodes,
    };

    g.generate();
}
