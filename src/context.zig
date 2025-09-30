const std = @import("std");

const cfg = @import("config.zig");
const img = @import("image.zig");

var allocator: std.mem.Allocator = undefined;

const Color = [3]u8;
const ColorTile1 = [8 * 8]Color;
pub var colorTiles1: [256]ColorTile1 = undefined;

const ColorTile = [cfg.bytePerTile]u8;

pub var colorTiles: [cfg.tilePerBank]ColorTile = undefined;

pub var nameTable1NotSame: bool = false;
pub var nameTable2NotSame: bool = false;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    @memset(std.mem.asBytes(colorTiles1[0..]), 0);
}

pub fn setTileRow(tileIndex: usize, row: usize, src: []const u8) void {
    std.debug.assert(src.len == cfg.bytePerTileRow);

    var colorTile = &colorTiles[tileIndex];
    const start = row * cfg.bytePerTileRow;
    @memcpy(colorTile[start .. start + src.len], src);
}

pub const WriteTileDesc = struct {
    buffer: []u8,
    tileX: usize,
    tileY: usize,
};

pub fn writeTile(dst: WriteTileDesc, tileIndex: usize) void {
    std.debug.assert(dst.buffer.len >= cfg.bytePerTile);

    // tile 坐标转字节坐标
    const x = dst.tileX * cfg.tileSize * cfg.pixelSize;
    const start = x + dst.tileY * cfg.tileSize * cfg.pixelPerRow * cfg.pixelSize;

    for (0..cfg.tileSize) |row| {
        const buffer = dst.buffer[start + row * cfg.bytePerRow ..];
        writeTileRow(buffer, tileIndex, row);
    }
}

pub fn writeTileRow(dst: []u8, tileIndex: usize, row: usize) void {
    std.debug.assert(dst.len >= cfg.bytePerTileRow);

    var colorTile = colorTiles[tileIndex];
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
        const tileX = tileIndex % cfg.tilePerRow;
        const tileY = tileIndex / cfg.tilePerRow;

        writeTile(.{ .buffer = backing, .tileX = tileX, .tileY = tileY }, tileIndex);
    }

    const size = cfg.pixelPerRow;
    const buffer = img.Buffer.init(size, size, backing);
    try buffer.write("out/31-tiles.ppm");
}
