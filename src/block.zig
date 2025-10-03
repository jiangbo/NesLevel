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
    buffer.drawGrid(16);
    try buffer.write("out/23-blocks-4x1.ppm");
}

pub fn writeSetBlock(allocator: std.mem.Allocator, set: ctx.HashSet) !void {
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

    const buffer = img.Buffer.init(width, height, backing);
    try buffer.write("out/24-blocks-set.ppm");
}

pub fn find(data: []const u8, set: ctx.HashSet) void {
    const u32Ptr: [*]const u32 = @ptrCast(@alignCast(data.ptr));
    const blocks = u32Ptr[0 .. data.len / 4];

    const GAP_LIMIT: usize = 4; // ≤4 个 u32 的 gap 不算断开

    var maxCount: usize = 0;
    var maxIndex: usize = 0;

    var currentCount: usize = 0; // 当前段内匹配到的项数量（仅匹配项）
    var currentStart: usize = 0; // 当前段第一个匹配项的索引
    var unmatched: usize = 0; // 自上次匹配以来未命中的连续数量
    var firstVal: u32 = 0; // 当前段第一个匹配的值
    var seenDifferent: bool = false; // 当前段内有没有与 firstVal 不同的匹配值

    for (blocks, 0..) |block, i| {
        if (set.contains(block)) {
            if (currentCount == 0) {
                // 新段开始
                currentStart = i;
                currentCount = 1;
                unmatched = 0;
                firstVal = block;
                seenDifferent = false;
            } else {
                // 已在段内
                if (unmatched > GAP_LIMIT) {
                    // gap 太大，前段终止 —— 在终止处做一次更新
                    if (seenDifferent and currentCount > maxCount) {
                        maxCount = currentCount;
                        maxIndex = currentStart;
                    }
                    // 从当前位置重新开始新段
                    currentStart = i;
                    currentCount = 1;
                    unmatched = 0;
                    firstVal = block;
                    seenDifferent = false;
                } else {
                    // gap 在容忍范围内，段继续，但不把 gap 加入 currentCount
                    currentCount += 1;
                    if (block != firstVal) seenDifferent = true;
                    unmatched = 0;
                }
            }

            // （可选）在这里也可更新 max，但我们在段结束 /继续时都做了检查，
            // 为保证不会错过最后一段，我们在 loop 末尾和段断开时都会检查。
        } else {
            // 非匹配项
            if (currentCount > 0) {
                unmatched += 1;
                if (unmatched > GAP_LIMIT) {
                    // 段真正断开，终止并记录（如果不是全相同）
                    if (seenDifferent and currentCount > maxCount) {
                        maxCount = currentCount;
                        maxIndex = currentStart;
                    }
                    // 重置，准备寻找下一段
                    currentCount = 0;
                    unmatched = 0;
                    seenDifferent = false;
                }
            } // else 不在任何段中，跳过
        }
    }

    // 到达末尾时，如果当前段仍然存在，做一次最终检查
    if (currentCount > 0) {
        if (seenDifferent and currentCount > maxCount) {
            maxCount = currentCount;
            maxIndex = currentStart;
        }
    }

    std.log.info("max index: 0x{x}, count: {d}", .{ maxIndex, maxCount });
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
