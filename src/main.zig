const std = @import("std");

const mem = @import("memory.zig");
const img = @import("pgm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const rom = try readFileAll(allocator, "rom/Feng Shen Bang.dmp");
    defer allocator.free(rom);

    const ppuMemory = mem.PPU.init(rom);

    printHex(ppuMemory.attrTable);

    try img.writePatternTable(ppuMemory);

    try img.writeNameTable("rom/nameTable0", ppuMemory.nameTable0, ppuMemory.patternTable0);

    if (!std.mem.eql(u8, ppuMemory.nameTable0, ppuMemory.nameTable1)) {
        try img.writeNameTable("rom/nameTable1", ppuMemory.nameTable1, ppuMemory.patternTable0);
    }

    if (!std.mem.eql(u8, ppuMemory.nameTable0, ppuMemory.nameTable2)) {
        try img.writeNameTable("rom/nameTable2", ppuMemory.nameTable2, ppuMemory.patternTable0);
    }
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
