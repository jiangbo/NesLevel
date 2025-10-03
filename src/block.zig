const std = @import("std");

const ctx = @import("context.zig");
const cfg = @import("config.zig");
const img = @import("image.zig");
const mem = @import("memory.zig");

pub fn write4x1(allocator: std.mem.Allocator, blocks: []const u8) !void {
    const blockSize = 2; // 每个 block 输出 2x2 tile
    const blocksPerRow = 8; // 图片每行放 8 个 block
    const blockPixelSize = cfg.tileSize * blockSize;

    const blockCount = blocks.len / 4;
    const rows = (blockCount + blocksPerRow - 1) / blocksPerRow;
    const width = blocksPerRow * blockPixelSize;
    const height = rows * blockPixelSize;

    const backing = try allocator.alloc(u8, width * height * 3);
    defer allocator.free(backing);
    @memset(backing, 0);

    for (0..blockCount) |i| {
        const baseTileX = (i % blocksPerRow) * blockSize;
        const baseTileY = (i / blocksPerRow) * blockSize;

        // 每个 block 内 4 个 tile
        for (0..4) |j| {
            const dx = j % 2;
            const dy = j / 2;
            const tileIndex = blocks[i * 4 + j];
            const absoluteTileIndex = (baseTileY + dy) * cfg.tilePerRow + (baseTileX + dx);
            ctx.writeTile(backing, absoluteTileIndex, tileIndex);
        }
    }

    const buf = img.Buffer.init(width, height, backing);
    try buf.write("out/23-blocks-4x1.ppm");
}

pub fn writeSetBlock(allocator: std.mem.Allocator, set: ctx.HashSet) !void {
    const blockPerRow = @divExact(cfg.tilePerRow, 2);
    const blockRows = try std.math.divCeil(usize, set.count(), blockPerRow);
    const totalTiles = (blockRows * 2) * cfg.tilePerRow;
    const len = totalTiles * cfg.bytePerTileCell;

    const backing = try allocator.alloc(u8, len);
    defer allocator.free(backing);
    @memset(backing, 0);

    var tileIndex: usize = 0;
    var iterator = set.iterator();
    while (iterator.next()) |block| {
        const bytes = std.mem.asBytes(block.key_ptr);
        for (bytes) |tile| {
            const pos = ctx.indexToPostion(tileIndex, 2, 2);
            ctx.writeTile(backing, pos, tile);
            tileIndex += 1;
        }
    }

    const width = cfg.pixelPerRow;
    const height = blockRows * 2 * cfg.tileSize;
    const buffer = img.Buffer.init(width, height, backing);
    try buffer.write("out/24-blocks-set.ppm");
}

fn collectBlocks2x2(allocator: std.mem.Allocator, nameTable: []u8) !std.AutoHashMap([4]u8, void) {
    var seen = std.AutoHashMap([4]u8, void).init(allocator);
    const blocksX = 32 / 2;
    const blocksY = 30 / 2;

    for (0..blocksY) |by| {
        for (0..blocksX) |bx| {
            const key = [4]u8{
                nameTable[(by * 2 + 0) * 32 + (bx * 2 + 0)],
                nameTable[(by * 2 + 0) * 32 + (bx * 2 + 1)],
                nameTable[(by * 2 + 1) * 32 + (bx * 2 + 0)],
                nameTable[(by * 2 + 1) * 32 + (bx * 2 + 1)],
            };
            _ = try seen.put(key, {});
        }
    }
    return seen;
}

fn writeBlocks2x2(allocator: std.mem.Allocator, seen: std.AutoHashMap([4]u8, void), path: []const u8) !void {
    const blockSize = 2;
    const tilePixel = cfg.tileSize;
    const blocksPerRow = 8;
    const width = blocksPerRow * blockSize * tilePixel;
    const rows = (seen.count() + blocksPerRow - 1) / blocksPerRow;
    const height = rows * blockSize * tilePixel;

    const backing = try allocator.alloc(u8, width * height * 3);
    defer allocator.free(backing);
    @memset(backing, 0);

    var it = seen.keyIterator();
    var blockIndex: usize = 0;
    while (it.next()) |block| : (blockIndex += 1) {
        const baseTileX = (blockIndex % blocksPerRow) * blockSize;
        const baseTileY = (blockIndex / blocksPerRow) * blockSize;

        for (0..blockSize * blockSize) |i| {
            const dx = i % blockSize;
            const dy = i / blockSize;
            const tileIndex = block[dy * blockSize + dx];
            ctx.writeTile(backing, baseTileY * cfg.tilePerRow + baseTileX + dy * cfg.tilePerRow + dx, tileIndex);
        }
    }

    const buffer = img.Buffer.init(width, height, backing);
    try buffer.write(path);
}

// fn collectBlocks4x4(allocator: std.mem.Allocator, nameTable: []u8) !std.AutoHashMap([16]u8, void) {
//     var seen = std.AutoHashMap([16]u8, void).init(allocator);
//     const blocksX = 32 / 4;
//     const blocksY = 30 / 4;

//     for (0..blocksY) |by| {
//         for (0..blocksX) |bx| {
//             var key: [16]u8 = undefined;
//             for (0..4) |dy| {
//                 for (0..4) |dx| {
//                     key[dy * 4 + dx] = nameTable[(by * 4 + dy) * 32 + (bx * 4 + dx)];
//                 }
//             }
//             _ = try seen.put(key, {});
//         }
//     }
//     return seen;
// }

// fn writeBlocks4x4(allocator: std.mem.Allocator, seen: std.AutoHashMap([16]u8, void), path: []const u8) !void {
//     const blockSize = 4;
//     const tilePixel = cfg.tileSize;
//     const blocksPerRow = 8;
//     const width = blocksPerRow * blockSize * tilePixel;
//     const rows = (seen.count() + blocksPerRow - 1) / blocksPerRow;
//     const height = rows * blockSize * tilePixel;

//     const backing = try allocator.alloc(u8, width * height * 3);
//     defer allocator.free(backing);
//     @memset(backing, 0);

//     var it = seen.keyIterator();
//     var blockIndex: usize = 0;
//     while (it.next()) |block| : (blockIndex += 1) {
//         const baseTileX = (blockIndex % blocksPerRow) * blockSize;
//         const baseTileY = (blockIndex / blocksPerRow) * blockSize;

//         for (0..blockSize * blockSize) |i| {
//             const dx = i % blockSize;
//             const dy = i / blockSize;
//             const tileIndex = block[dy * blockSize + dx];
//             ctx.writeTile(backing, baseTileY * cfg.tilePerRow + baseTileX + dy * cfg.tilePerRow + dx, tileIndex);
//         }
//     }

//     const buffer = image.Buffer.init(width, height, backing);
//     try buffer.write(path);
// }

pub fn write2x2(allocator: std.mem.Allocator, ppu: mem.PPU) !void {
    var seen = try collectBlocks2x2(allocator, ppu.nameTable2);
    defer seen.deinit();
    try writeBlocks2x2(allocator, seen, "out/21-blocks-2x2.ppm");
}

// pub fn write4x4(allocator: std.mem.Allocator, ppu: mem.PPU) !void {
//     var seen = try collectBlocks4x4(allocator, ppu.nameTable2);
//     defer seen.deinit();
//     try writeBlocks4x4(allocator, seen, "out/22-blocks-4x4.ppm");
// }
