const std = @import("std");

var allocator: std.mem.Allocator = undefined;

const Color = [3]u8;
const ColorTile = [8 * 8]Color;

pub var colorTiles: [256]ColorTile = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    @memset(std.mem.asBytes(colorTiles[0..]), 0);
}
