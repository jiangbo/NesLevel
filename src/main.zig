const std = @import("std");

const ctx = @import("context.zig");
const mem = @import("memory.zig");
const block = @import("block.zig");
const pgm = @import("pgm.zig");
const ppm = @import("ppm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const ppuDump = try readFileAll(allocator, "rom/Feng Shen Bang.dmp");
    defer allocator.free(ppuDump);

    ctx.init(allocator);

    const ppu = mem.PPU.init(ppuDump);
    printHex(ppu.palette);

    try pgm.writePatternTable(ppu);
    try pgm.writeNameTable(ppu);

    try ppm.writePatternTable(ppu);
    try ppm.writeNameTable(ppu);

    try block.write2x2(allocator, ppu);
}

fn readFileAll(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

pub fn printHex(hex: []const u8) void {
    for (hex, 0..) |value, i| {
        if (i % 16 == 0) {
            std.debug.print("\n{X:04}: ", .{i});
        }
        std.debug.print("{X:0>2} ", .{value});
    }
    std.debug.print("\n", .{});
}
