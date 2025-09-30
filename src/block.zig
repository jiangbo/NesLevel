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
            const idx0 = ppu.nameTable0[(by * 2) * 32 + (bx * 2)];
            const idx1 = ppu.nameTable0[(by * 2) * 32 + (bx * 2 + 1)];
            const idx2 = ppu.nameTable0[(by * 2 + 1) * 32 + (bx * 2)];
            const idx3 = ppu.nameTable0[(by * 2 + 1) * 32 + (bx * 2 + 1)];

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
    var i: usize = 0;
    while (it.next()) |block| {
        const baseX = (i % blocksPerRow) * blockSize;
        const baseY = (i / blocksPerRow) * blockSize;

        for (0..2) |dy| {
            for (0..2) |dx| {
                const tileIndex = block.*[dy * 2 + dx];

                const tilePixels = ctx.colorTiles[tileIndex];

                for (0..8) |ty| {
                    for (0..8) |tx| {
                        const rgb = tilePixels[ty * 8 + tx];
                        const px = baseX + dx * 8 + tx;
                        const py = baseY + dy * 8 + ty;
                        const idx = (py * width + px) * 3;
                        backing[idx + 0] = rgb[0];
                        backing[idx + 1] = rgb[1];
                        backing[idx + 2] = rgb[2];
                    }
                }
            }
        }
        i += 1;
    }

    const buffer = image.Buffer.init(width, height, backing);
    try buffer.write("out/21-blocks.ppm");
}

// pub fn write4x4(allocator: std.mem.Allocator, ppu: mem.PPU) !void {
//     // TODO
//     return error.NotImplemented;
// }

// pub fn write(allocator: std.mem.Allocator, ppu: mem.PPU, width: u16, height: u16) !void {}
