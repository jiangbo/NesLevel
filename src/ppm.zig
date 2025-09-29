const std = @import("std");

const mem = @import("memory.zig");
const cache = @import("cache.zig");

pub const Buffer = struct {
    data: []u8, // width * height * 3
    width: usize,
    height: usize,

    attrTable: []const u8 = &.{},
    palette: []const u8 = &.{},

    fn init(data: []u8, width: usize, height: usize) Buffer {
        std.debug.assert(data.len == width * height * 3);
        return Buffer{ .data = data, .width = width, .height = height };
    }

    fn drawTile(self: *Buffer, tile: mem.Tile, isCache: bool) void {
        const attrIndex = (tile.y & 0b11100) << 1 | tile.x >> 2;
        const attrByte = self.attrTable[attrIndex];

        const shift: u3 = @intCast(tile.y & 0b10 | (tile.x & 0b10) >> 1);
        const paletteGroup = attrByte >> shift * 2 & 0b11;

        const baseX, const baseY = .{ tile.x * 8, tile.y * 8 };

        var colorTile = &cache.colorTiles[tile.index];

        for (0..8) |row| {
            const b0 = tile.plane0[row];
            const b1 = tile.plane1[row];
            const rowOffset = (baseY + row) * self.width * 3;

            for (0..8) |col| {
                const bit: u3 = @intCast(7 ^ col);
                const lo = (b0 >> bit) & 1;
                const hi = (b1 >> bit) & 1;
                const index: u8 = @intCast((hi << 1) | lo);

                var paletteIndex = paletteGroup * 4 + index;
                if (index == 0) paletteIndex = 0;

                const colorIndex = self.palette[paletteIndex];
                const idx = rowOffset + (baseX + col) * 3;
                const rgb = systemPalette[colorIndex * 3 ..][0..3];
                @memcpy(self.data[idx..][0..3], rgb);

                if (isCache) @memcpy(&colorTile[row + col * 8], rgb);
            }
        }
    }

    fn write(self: Buffer, name: []const u8) !void {
        var buffer: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&buffer, "{s}.ppm", .{name});

        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writer().print("P6\n{} {}\n255\n", .{
            self.width,
            self.height,
        });
        try file.writeAll(self.data);
    }
};

const systemPalette = @embedFile("nes2.pal");

pub fn writePatternTable(ppu: mem.PPU) !void {
    const width = 128;
    const height = 128;

    var backing: [width * height * 3]u8 = undefined;
    var buffer = Buffer.init(&backing, width, height);

    fillPatternBuffer(&buffer, ppu, 0);
    try buffer.write("rom/pattern0");

    fillPatternBuffer(&buffer, ppu, 1);
    try buffer.write("rom/pattern1");
}

fn fillPatternBuffer(buffer: *Buffer, ppu: mem.PPU, i: u8) void {
    const table = switch (i) {
        0 => ppu.patternTable0,
        1 => ppu.patternTable1,
        else => @panic("invalid pattern table index"),
    };

    buffer.attrTable = &[_]u8{0} ** 64;
    buffer.palette = ppu.palette;

    for (0..table.len / 16) |index| {
        const offset = index * 16;
        const tile = mem.Tile{
            .index = index,
            .x = index & 0b1111,
            .y = index >> 4,
            .plane0 = table[offset..][0..8],
            .plane1 = table[offset + 8 ..][0..8],
        };
        buffer.drawTile(tile, false);
    }
}

pub fn writeNameTable(ppu: mem.PPU) !void {
    const width = 256; // 32 tiles * 8
    const height = 240; // 30 tiles * 8

    var backing: [width * height * 3]u8 = undefined;
    var buffer = Buffer.init(&backing, width, height);
    buffer.attrTable = ppu.nameTable0[mem.PPU.attrIndex..];
    buffer.palette = ppu.palette;

    fillNameBuffer(&buffer, ppu, 0, 0);
    try buffer.write("rom/nameTable0");

    if (!std.mem.eql(u8, ppu.nameTable0, ppu.nameTable1)) {
        buffer.attrTable = ppu.nameTable1[mem.PPU.attrIndex..];
        fillNameBuffer(&buffer, ppu, 1, 0);
        try buffer.write("rom/nameTable1");
    }

    if (!std.mem.eql(u8, ppu.nameTable0, ppu.nameTable2)) {
        buffer.attrTable = ppu.nameTable2[mem.PPU.attrIndex..];
        fillNameBuffer(&buffer, ppu, 2, 0);
        try buffer.write("rom/nameTable2");
    }
}

fn fillNameBuffer(buffer: *Buffer, ppu: mem.PPU, ni: u8, pi: u8) void {
    const nameTable = switch (ni) {
        0 => ppu.nameTable0,
        1 => ppu.nameTable1,
        2 => ppu.nameTable2,
        3 => ppu.nameTable3,
        else => @panic("invalid name table index"),
    };

    const patternTable = switch (pi) {
        0 => ppu.patternTable0,
        1 => ppu.patternTable1,
        else => @panic("invalid pattern table index"),
    };

    for (0..mem.PPU.attrIndex) |index| {
        const offset = @as(usize, nameTable[index]) * 16;
        const tile = mem.Tile{
            .index = nameTable[index],
            .x = index & 0b11111,
            .y = index >> 5,
            .plane0 = patternTable[offset..][0..8],
            .plane1 = patternTable[offset + 8 ..][0..8],
        };

        buffer.drawTile(tile, true);
    }
}

// pub fn writeBlocks(allocator: std.mem.Allocator, ppu: mem.PPU) !void {
//     const blockSize = 16; // 每个 block 是 16x16 像素
//     const blocksX = 32 / 2;
//     const blocksY = 30 / 2;

//     // 用 HashMap 去重
//     var seen = std.AutoHashMap([4]u8, void).init(allocator);
//     defer seen.deinit();

//     var uniqueBlocks = std.ArrayList([4]u8).init(allocator);
//     defer uniqueBlocks.deinit();

//     // 遍历屏幕，提取所有 2x2 block
//     for (0..blocksY) |by| {
//         for (0..blocksX) |bx| {
//             const idx0 = ppu.nameTable0[(by * 2) * 32 + (bx * 2)];
//             const idx1 = ppu.nameTable0[(by * 2) * 32 + (bx * 2 + 1)];
//             const idx2 = ppu.nameTable0[(by * 2 + 1) * 32 + (bx * 2)];
//             const idx3 = ppu.nameTable0[(by * 2 + 1) * 32 + (bx * 2 + 1)];

//             const key = [4]u8{ idx0, idx1, idx2, idx3 };

//             if (!seen.contains(key)) {
//                 try seen.put(key, {});
//                 try uniqueBlocks.append(key);
//             }
//         }
//     }

//     // 输出图像大小：每行 8 个 block
//     const blocksPerRow = 8;
//     const rows = (uniqueBlocks.items.len + blocksPerRow - 1) / blocksPerRow;
//     const width = blocksPerRow * blockSize;
//     const height = rows * blockSize;

//     const backing = try allocator.alloc(u8, width * height * 3);
//     defer allocator.free(backing);

//     var buffer = Buffer.init(backing, width, height);
//     buffer.attrTable = ppu.nameTable0[mem.PPU.attrIndex..];
//     buffer.palette = ppu.palette;

//     // 绘制每个唯一 block
//     for (uniqueBlocks.items, 0..) |block, i| {
//         const bx = (i % blocksPerRow) * 2;
//         const by = (i / blocksPerRow) * 2;

//         for (0..2) |dy| {
//             for (0..2) |dx| {
//                 const tileIndex = block[dy * 2 + dx];
//                 const offset = @as(usize, tileIndex) * 16;

//                 const tile = mem.Tile{
//                     .index = tileIndex,
//                     .x = bx + dx,
//                     .y = by + dy,
//                     .plane0 = ppu.patternTable0[offset..][0..8],
//                     .plane1 = ppu.patternTable0[offset + 8 ..][0..8],
//                 };
//                 buffer.drawTile(tile);
//             }
//         }
//     }

//     try buffer.write("rom/blocks");
// }
