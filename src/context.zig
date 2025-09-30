const std = @import("std");

var allocator: std.mem.Allocator = undefined;

const Color = [3]u8;
const ColorTile = [8 * 8]Color;

pub var colorTiles: [256]ColorTile = undefined;

pub var nameTable1NotSame: bool = false;
pub var nameTable2NotSame: bool = false;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    @memset(std.mem.asBytes(colorTiles[0..]), 0);
}
