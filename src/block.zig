const std = @import("std");

const mem = @import("memory.zig");
const ctx = @import("context.zig");
const cfg = @import("config.zig");
const image = @import("image.zig");

fn collect2x2Blocks(allocator: std.mem.Allocator, nameTable: []u8) !std.AutoHashMap([4]u8, void) {
    var seen = std.AutoHashMap([4]u8, void).init(allocator);
    const blocksX = 32 / 2;
    const blocksY = 30 / 2;

    for (0..blocksY) |by| {
        for (0..blocksX) |bx| {
            const idx0 = nameTable[(by * 2) * 32 + (bx * 2)];
            const idx1 = nameTable[(by * 2) * 32 + (bx * 2 + 1)];
            const idx2 = nameTable[(by * 2 + 1) * 32 + (bx * 2)];
            const idx3 = nameTable[(by * 2 + 1) * 32 + (bx * 2 + 1)];
            const key = [4]u8{ idx0, idx1, idx2, idx3 };
            _ = try seen.put(key, {});
        }
    }
    return seen;
}

fn write2x2BlocksToImage(allocator: std.mem.Allocator, seen: std.AutoHashMap([4]u8, void), path: []const u8) !void {
    const blockSize = 2;
    const blockPixelSize = cfg.tileSize * blockSize;
    const blocksPerRow = 8;
    const rows = (seen.count() + blocksPerRow - 1) / blocksPerRow;
    const width = blocksPerRow * blockPixelSize;
    const height = rows * blockPixelSize;

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

    const buffer = image.Buffer.init(width, height, backing);
    try buffer.write(path);
}

fn write4x4BlocksToImage(allocator: std.mem.Allocator, seen: std.AutoHashMap([16]u8, void), path: []const u8) !void {
    const blockSize = 4;
    const blockPixelSize = cfg.tileSize * blockSize;
    const blocksPerRow = 8;
    const rows = (seen.count() + blocksPerRow - 1) / blocksPerRow;
    const width = blocksPerRow * blockPixelSize;
    const height = rows * blockPixelSize;

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

    const buffer = image.Buffer.init(width, height, backing);
    try buffer.write(path);
}

fn collect4x4Blocks(allocator: std.mem.Allocator, nameTable: []u8) !std.AutoHashMap([16]u8, void) {
    var seen = std.AutoHashMap([16]u8, void).init(allocator);
    const blocksX = 32 / 4;
    const blocksY = 30 / 4;

    for (0..blocksY) |by| {
        for (0..blocksX) |bx| {
            var key: [16]u8 = undefined;
            for (0..4) |dy| {
                for (0..4) |dx| {
                    key[dy * 4 + dx] = nameTable[(by * 4 + dy) * 32 + (bx * 4 + dx)];
                }
            }
            _ = try seen.put(key, {});
        }
    }
    return seen;
}

pub fn write2x2(allocator: std.mem.Allocator, ppu: mem.PPU) !void {
    var seen = try collect2x2Blocks(allocator, ppu.nameTable2);
    defer seen.deinit();
    try write2x2BlocksToImage(allocator, seen, "out/21-blocks-2x2.ppm");
}

pub fn write4x4(allocator: std.mem.Allocator, ppu: mem.PPU) !void {
    var seen = try collect4x4Blocks(allocator, ppu.nameTable2);
    defer seen.deinit();
    try write4x4BlocksToImage(allocator, seen, "out/22-blocks-4x4.ppm");
}
