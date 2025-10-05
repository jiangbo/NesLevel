const std = @import("std");

const cfg = @import("config.zig");
const img = @import("image.zig");
const mem = @import("memory.zig");

const ColorTile = [cfg.bytePerTileCell]u8;

var allocator: std.mem.Allocator = undefined;
pub var colorTiles: [cfg.tilePerBank]ColorTile = undefined;

pub var nameTable1NotSame: bool = false;
pub var nameTable2NotSame: bool = false;

pub const HashMap = std.AutoArrayHashMapUnmanaged(u32, u8);
pub var block2x2Set: HashMap = .empty;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    @memset(std.mem.asBytes(colorTiles[0..]), 0);
}

pub fn deinit() void {
    block2x2Set.deinit(allocator);
}

pub fn setTileRow(index: usize, row: usize, src: []const u8) void {
    std.debug.assert(src.len == cfg.bytePerTileRow);

    var colorTile = &colorTiles[index];
    const start = row * cfg.bytePerTileRow;
    @memcpy(colorTile[start..][0..src.len], src);
}

pub fn writeTile(buffer: []u8, dst: usize, src: usize) void {
    std.debug.assert(buffer.len >= cfg.bytePerTileCell);

    const pos = indexToPostion(dst, 2, 2);
    // tile 坐标转字节坐标
    const x = (pos % cfg.tilePerRow) * cfg.bytePerTileRow;
    const tileY = pos / cfg.tilePerRow;
    const start = x + tileY * cfg.tileSize * cfg.bytePerRow;

    for (0..cfg.tileSize) |row| {
        const buf = buffer[start + row * cfg.bytePerRow ..];
        writeTileRow(buf, src, row);
    }
}

fn indexToPostion(index: usize, width: usize, height: usize) usize {
    const tilesPerBlock = width * height;
    const blockIndex = index / tilesPerBlock;
    const tileInBlock = index % tilesPerBlock;

    const blocksPerRow = @divExact(cfg.tilePerRow, width);
    const blockX = blockIndex % blocksPerRow;
    const blockY = blockIndex / blocksPerRow;

    const startY = blockY * height * cfg.tilePerRow;
    const start = startY + blockX * width;

    const inRow = tileInBlock / width;
    const inCol = tileInBlock % width;

    return start + inRow * cfg.tilePerRow + inCol;
}

pub fn writeTileRow(dst: []u8, tileIndex: usize, row: usize) void {
    std.debug.assert(dst.len >= cfg.bytePerTileRow);

    var colorTile = &colorTiles[tileIndex];
    const start = row * cfg.bytePerTileRow;
    const src = colorTile[start..][0..cfg.bytePerTileRow];
    @memcpy(dst[0..cfg.bytePerTileRow], src);
}

pub fn readTileRow(tileIndex: usize, row: usize) []const u8 {
    const colorTile = &colorTiles[tileIndex];
    const start = row * cfg.bytePerTileRow;
    return colorTile[start..][0..cfg.bytePerTileRow];
}

pub fn writeAllTiles() !void {
    const backing = try allocator.alloc(u8, cfg.bytePerBank);
    defer allocator.free(backing);
    @memset(backing, 0);

    for (0..colorTiles.len) |index| {
        writeTile(backing, index, index);
    }

    const size = cfg.pixelPerRow;
    const buffer = img.Buffer.init(size, size, backing);
    try buffer.write("out/18-tiles.ppm");
}

// pub fn extract2x2Blocks(tiles: []const u8) !void {
//     std.debug.assert(tiles.len % 4 == 0);

//     const u32Ptr: [*]const u32 = @ptrCast(@alignCast(tiles.ptr));
//     const blocks = u32Ptr[0 .. tiles.len / 4];

//     try block2x2Set.ensureTotalCapacity(allocator, blocks.len);
//     for (blocks) |value| block2x2Set.putAssumeCapacity(value, {});
//     block2x2Set.shrinkAndFree(allocator, block2x2Set.count());

//     std.log.info("2x2 block count: {d}", .{block2x2Set.count()});
// }

pub fn extract2x2Blocks(nametable: []const u8) !void {
    const tiles = nametable[0..mem.PPU.attrIndex];
    const attributes = nametable[mem.PPU.attrIndex..];
    std.debug.assert(tiles.len % 4 == 0);

    try block2x2Set.ensureTotalCapacity(allocator, tiles.len / 4);

    var index: usize = 0;
    var attributeIndex: usize = 0;
    while (index + cfg.nameTableCols < tiles.len) : (index += 4) {
        if ((index / cfg.nameTableCols) % 4 != 0) continue;

        // std.log.info("index: {}, attribute index: {}", .{ index, attributeIndex });
        for (0..4) |i| {
            const offset: usize = switch (i) {
                0 => 0,
                1 => 2,
                2 => cfg.nameTableCols * 2,
                3 => cfg.nameTableCols * 2 + 2,
                else => unreachable,
            };
            const next = index + cfg.nameTableCols + offset;
            if (next > tiles.len) break;
            const array = [_]u8{
                tiles[index + offset], tiles[index + offset + 1],
                tiles[next],           tiles[next + 1],
            };
            const value = std.mem.bytesToValue(u32, &array);
            const attr = attributes[attributeIndex];

            const color_mask: u8 = switch (i) {
                0 => 0b00000011, // 左上
                1 => 0b00001100, // 右上
                2 => 0b00110000, // 左下
                3 => 0b11000000, // 右下
                else => unreachable,
            };
            const color = attr & color_mask;
            // const shift: u3 = @intCast(i * 2);
            // const color: u8 = (attr >> shift) & 0b11;
            block2x2Set.putAssumeCapacity(value, color);
        }
        attributeIndex += 1;
    }

    block2x2Set.shrinkAndFree(allocator, block2x2Set.count());
    std.log.info("2x2 block count: {d}", .{block2x2Set.count()});
}
