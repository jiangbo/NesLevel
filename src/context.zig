const std = @import("std");

const cfg = @import("config.zig");
const img = @import("image.zig");

var allocator: std.mem.Allocator = undefined;

const Color = [3]u8;
const ColorTile1 = [8 * 8]Color;
pub var colorTiles1: [256]ColorTile1 = undefined;

const ColorTile = [cfg.bytePerTileCell]u8;

pub var colorTiles: [cfg.tilePerBank]ColorTile = undefined;

pub var nameTable1NotSame: bool = false;
pub var nameTable2NotSame: bool = false;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    @memset(std.mem.asBytes(colorTiles1[0..]), 0);
}

pub fn setTileRow(index: usize, row: usize, src: []const u8) void {
    std.debug.assert(src.len == cfg.bytePerTileRow);

    var colorTile = &colorTiles[index];
    const start = row * cfg.bytePerTileRow;
    @memcpy(colorTile[start..][0..src.len], src);
}

pub fn writeTile(buffer: []u8, dst: usize, src: usize) void {
    std.debug.assert(buffer.len >= cfg.bytePerTileCell);

    // tile 坐标转字节坐标
    const x = (dst % cfg.tilePerRow) * cfg.bytePerTileRow;
    const tileY = dst / cfg.tilePerRow;
    const start = x + tileY * cfg.tileSize * cfg.bytePerRow;

    for (0..cfg.tileSize) |row| {
        const buf = buffer[start + row * cfg.bytePerRow ..];
        writeTileRow(buf, src, row);
    }
}

pub fn writeTileRow(dst: []u8, tileIndex: usize, row: usize) void {
    std.debug.assert(dst.len >= cfg.bytePerTileRow);

    var colorTile = &colorTiles[tileIndex];
    const start = row * cfg.bytePerTileRow;
    const src = colorTile[start..][0..cfg.bytePerTileRow];
    @memcpy(dst[0..cfg.bytePerTileRow], src);
}

pub fn readTileRow(tileIndex: usize, row: usize) []const u8 {
    const colorTile = colorTiles[tileIndex];
    const start = row * cfg.bytePerTileRow;
    return colorTile[start..][0..cfg.bytePerTileRow];
}

pub fn writeAllTiles() !void {
    const backing = try allocator.alloc(u8, cfg.bytePerBank);
    defer allocator.free(backing);
    @memset(backing, 0);

    for (0..colorTiles.len) |tileIndex| {
        writeTile(backing, tileIndex, tileIndex);
    }

    const size = cfg.pixelPerRow;
    const buffer = img.Buffer.init(size, size, backing);
    try buffer.write("out/31-tiles.ppm");
}
