const std = @import("std");

pub fn usizeToStr(n: f64) ![]const u8 {
    var buffer: [4096]u8 = undefined;
    const result = std.fmt.bufPrintZ(buffer[0..], "{d}", .{n}) catch unreachable;
    return result;
}
