const std = @import("std");

const ctx = @import("context.zig");
const cfg = @import("config.zig");
const img = @import("image.zig");
const mem = @import("memory.zig");

const divCeil = std.math.divCeil;

pub fn write4x1(allocator: std.mem.Allocator, tiles: []const u8) !void {
    const blockPerRow = @divExact(cfg.tilePerRow, 2);
    const blockRows = try divCeil(usize, tiles.len / 4, blockPerRow);

    const width = blockPerRow * (cfg.tileSize * 2);
    const height = blockRows * (cfg.tileSize * 2);

    const backing = try allocator.alloc(u8, width * height * cfg.pixelSize);
    defer allocator.free(backing);
    @memset(backing, 0);

    for (tiles, 0..) |tileIndex, index| {
        ctx.writeTile(backing, index, tileIndex);
    }

    var buffer = img.Buffer.init(width, height, backing);
    buffer.draw16x16Grid();
    try buffer.write("out/23-blocks-4x1.ppm");
}

pub fn writeSetBlock(allocator: std.mem.Allocator, set: ctx.HashMap) !void {
    const blockPerRow = @divExact(cfg.tilePerRow, 2);
    const blockRows = try divCeil(usize, set.count(), blockPerRow);

    const width = blockPerRow * (cfg.tileSize * 2);
    const height = blockRows * (cfg.tileSize * 2);

    const backing = try allocator.alloc(u8, width * height * cfg.pixelSize);
    defer allocator.free(backing);
    @memset(backing, 0);

    var index: usize = 0;
    var iterator = set.iterator();
    while (iterator.next()) |block| {
        const bytes = std.mem.asBytes(block.key_ptr);
        for (bytes) |tile| {
            ctx.writeTile(backing, index, tile);
            index += 1;
        }
    }

    var buffer = img.Buffer.init(width, height, backing);
    buffer.draw16x16Grid();
    try buffer.write("out/24-blocks-set.ppm");
}

pub fn findBlock(data: []const u8, set: ctx.HashMap) void {
    const u32Ptr: [*]const u32 = @ptrCast(@alignCast(data.ptr));
    const blocks = u32Ptr[0 .. data.len / 4];

    var maxCount: usize = 0;
    var currentCount: usize = 0;
    var maxIndex: usize = 0;
    var currentIndex: usize = 0;

    var previous: u32 = 0;
    var gap: usize = 0;
    for (blocks, 0..) |block, i| {
        if (block == previous) continue; // 不处理连续相同的
        previous = block;

        if (set.contains(block)) {
            if (currentCount == 0) currentIndex = i;

            gap = 0;
            currentCount += 1;
            // std.log.info("index: {X}, block: {X}, color: {?b}", .{
            //     i * 4,
            //     block,
            //     set.get(block),
            // });

            if (currentCount > maxCount) {
                maxCount = currentCount;
                maxIndex = currentIndex;
            }
        } else if (gap > 8) currentCount = 0 //
        else gap += 1;
    }

    const addr = maxIndex * 4;
    std.log.info("max index: 0x{x}, count: {d}", .{ addr, maxCount });
    std.log.info("PRG index: 0x{x}", .{addr - 0x10});
}

pub fn writeAttributeBlock(allocator: std.mem.Allocator, tiles: []const u8) !void {
    const blockPerRow = @divExact(cfg.tilePerRow, 2);
    const blockRows = try divCeil(usize, tiles.len / 4, blockPerRow);

    const width = blockPerRow * (cfg.tileSize * 2);
    const height = blockRows * (cfg.tileSize * 2);

    const backing = try allocator.alloc(u8, width * height * cfg.pixelSize);
    defer allocator.free(backing);
    @memset(backing, 0);

    for (tiles, 0..) |tileIndex, index| {
        ctx.writeAttributeTile(backing, index, tileIndex);
    }

    var buffer = img.Buffer.init(width, height, backing);
    buffer.draw16x16Grid();
    try buffer.write("out/25-attr-blocks.ppm");
}

const LevelDesc = struct {
    blockIndexes: []const u8,
    widthBlock: usize,
    heightBlock: usize,
    tilePerRow: usize,
};

pub fn writeLevel(allocator: std.mem.Allocator, desc: LevelDesc) !void {
    const len = desc.widthBlock * desc.heightBlock;
    std.debug.assert(desc.blockIndexes.len == len);

    const width = desc.widthBlock * 2 * cfg.tileSize;
    const height = desc.heightBlock * 2 * cfg.tileSize;

    const backing = try allocator.alloc(u8, width * height * cfg.pixelSize);
    defer allocator.free(backing);
    @memset(backing, 0);

    for (desc.blockIndexes, 0..) |blockIndex, index| {
        const i: usize = blockIndex;
        const tiles = ctx.blockDef[i * 4 ..][0..4];

        const tileX = (index % desc.widthBlock) * 2;
        const tileY = (index / desc.widthBlock) * 2;

        for (tiles, 0..) |tileIndex, t| {
            ctx.writeTileDesc(backing, .{
                .tileIndex = tileIndex,
                .tileX = tileX + t % 2,
                .tileY = tileY + t / 2,
                .tilePerRow = desc.tilePerRow,
            });
        }
    }

    var buffer = img.Buffer.init(width, height, backing);
    // buffer.draw16x16Grid();
    try buffer.write("out/26-level.ppm");
}

pub fn findAttribute(data: []const u8, set: ctx.HashSet) void {
    var maxCount: usize = 0;
    var currentCount: usize = 0;
    var maxIndex: usize = 0;
    var currentIndex: usize = 0;

    var previous: u32 = 0;
    var gap: usize = 0;
    for (data, 0..) |block, i| {
        if (block == previous) continue; // 不处理连续相同的
        previous = block;

        if (set.contains(block)) {
            if (currentCount == 0) currentIndex = i;

            gap = 0;
            currentCount += 1;

            if (currentCount > maxCount) {
                maxCount = currentCount;
                maxIndex = currentIndex;
            }
        } else if (gap > 8) currentCount = 0 //
        else gap += 1;
    }

    std.log.info("max index: 0x{x}, count: {d}", .{ maxIndex, maxCount });
    std.log.info("PRG index: 0x{x}", .{maxIndex - 0x10});
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
