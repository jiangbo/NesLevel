const std = @import("std");

const mem = @import("memory.zig");
const ctx = @import("context.zig");
const image = @import("image.zig");

pub fn write2x2(allocator: std.mem.Allocator, ppu: mem.PPU) !void {
    const blockSize = 16;
    const blocksX = 32 / 2;
    const blocksY = 30 / 2;

    // 只用一个 HashMap 存唯一 block
    var seen = std.AutoHashMap([4]u8, void).init(allocator);
    defer seen.deinit();

    for (0..blocksY) |by| {
        for (0..blocksX) |bx| {
            const idx0 = ppu.nameTable2[(by * 2) * 32 + (bx * 2)];
            const idx1 = ppu.nameTable2[(by * 2) * 32 + (bx * 2 + 1)];
            const idx2 = ppu.nameTable2[(by * 2 + 1) * 32 + (bx * 2)];
            const idx3 = ppu.nameTable2[(by * 2 + 1) * 32 + (bx * 2 + 1)];

            const key = [4]u8{ idx0, idx1, idx2, idx3 };
            _ = try seen.put(key, {}); // 已存在则覆盖，无影响
        }
    }

    // 计算输出大小
    const blocksPerRow = 8;
    const rows = (seen.count() + blocksPerRow - 1) / blocksPerRow;
    const width = blocksPerRow * blockSize;
    const height = rows * blockSize;

    const backing = try allocator.alloc(u8, width * height * 3);
    defer allocator.free(backing);
    @memset(backing, 0);

    // 遍历 HashMap 的 key，直接绘制
    var it = seen.keyIterator();
    var blockIndex: usize = 0;
    while (it.next()) |block| : (blockIndex += 1) {
        const baseTileX = (blockIndex % blocksPerRow) * 2;
        const baseTileY = (blockIndex / blocksPerRow) * 2;

        for (block, 0..) |tileIndex, index| {
            var tileX: usize, var tileY: usize = .{ 0, 0 };
            if ((index & 0b01) != 0) tileX += 1;
            if ((index & 0b10) != 0) tileY += 1;

            const writeTileDesc = ctx.WriteTileDesc{
                .buffer = backing,
                .tileX = baseTileX + tileX,
                .tileY = baseTileY + tileX,
            };
            ctx.writeTile(writeTileDesc, tileIndex);
        }
    }

    const buffer = image.Buffer.init(width, height, backing);
    try buffer.write("out/21-blocks.ppm");
}

const tilePerRow = 16; // 每行存 16 个 tile
const tileSize = 8; // 每个 tile 8x8
const pixelPerRow = tilePerRow * tileSize; // 每行的像素
const pixelSize = 3; // 每个像素 3 个字节
const bytesPerRow = pixelPerRow * pixelSize; // 每行的字节数

// fn writeTile(buffer: []u8, tileX: usize, tileY: usize, tileIndex: u8) void {
//     // tile 坐标转像素坐标
//     const x, const y = .{ tileX * tileSize, tileY * tileSize };

//     for (0..tileSize) |row| { // 一行一行绘制
//         // x 坐标不变，y 坐标递增
//         const offsetY = y + row * tileSize;

//         // 从缓存获取 tile 的像素数据
//         const tilePixels = ctx.colorTiles[tileIndex];

//         var dest = buffer[offsetY * width + x ..];
//     }
// }

// pub fn write4x4(allocator: std.mem.Allocator, ppu: mem.PPU) !void {
//     // TODO
//     return error.NotImplemented;
// }

// pub fn write(allocator: std.mem.Allocator, ppu: mem.PPU, width: u16, height: u16) !void {}
