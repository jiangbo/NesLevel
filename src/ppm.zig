const std = @import("std");

const mem = @import("memory.zig");
const ctx = @import("context.zig");
const img = @import("image.zig");

pub const Buffer = struct {
    data: []u8, // width * height * 3
    width: u32,
    height: u32,

    attrTable: []const u8 = &.{},
    palette: []const u8 = &.{},

    fn init(data: []u8, width: u32, height: u32) Buffer {
        return Buffer{ .data = data, .width = width, .height = height };
    }

    fn drawTile(self: *Buffer, tile: mem.Tile, isCache: bool) void {
        const attrIndex = (tile.y & 0b11100) << 1 | tile.x >> 2;
        const attrByte = self.attrTable[attrIndex];

        const shift: u3 = @intCast(tile.y & 0b10 | (tile.x & 0b10) >> 1);
        const paletteGroup = attrByte >> shift * 2 & 0b11;

        const baseX, const baseY = .{ tile.x * 8, tile.y * 8 };

        var colorTile = &ctx.colorTiles[tile.index];

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
                const rgb = systemPalette[colorIndex * 3 ..][0..3];
                const idx = rowOffset + (baseX + col) * 3;
                @memcpy(self.data[idx..][0..3], rgb);

                if (isCache) @memcpy(&colorTile[row * 8 + col], rgb);
            }
        }
    }

    fn toImageBuffer(self: Buffer) img.Buffer {
        return .init(self.width, self.height, self.data);
    }
};

const systemPalette = @embedFile("nes2.pal");

pub fn writePatternTable(ppu: mem.PPU) !void {
    const width = 128;
    const height = 128;

    var backing: [width * height * 3]u8 = undefined;
    var buffer = Buffer.init(&backing, width, height);

    fillPatternBuffer(&buffer, ppu, 0);
    try buffer.toImageBuffer().write("rom/pattern0.ppm");

    fillPatternBuffer(&buffer, ppu, 1);
    try buffer.toImageBuffer().write("rom/pattern1.ppm");
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
    try buffer.toImageBuffer().write("rom/nameTable0.ppm");

    if (ctx.nameTable1NotSame) {
        buffer.attrTable = ppu.nameTable1[mem.PPU.attrIndex..];
        fillNameBuffer(&buffer, ppu, 1, 0);
        try buffer.toImageBuffer().write("rom/nameTable1.ppm");
    }

    if (!ctx.nameTable2NotSame) {
        buffer.attrTable = ppu.nameTable2[mem.PPU.attrIndex..];
        fillNameBuffer(&buffer, ppu, 2, 0);
        try buffer.toImageBuffer().write("rom/nameTable2.ppm");
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
