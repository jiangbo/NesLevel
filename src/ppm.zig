const std = @import("std");

const mem = @import("memory.zig");

pub const Buffer = struct {
    data: []u8, // width * height * 3
    width: usize,
    height: usize,

    attrTable: []const u8 = &.{},
    palette: []const u8 = &.{},

    pub fn init(data: []u8, width: usize, height: usize) Buffer {
        std.debug.assert(data.len == width * height * 3);
        return Buffer{ .data = data, .width = width, .height = height };
    }

    fn drawTile(self: *Buffer, tile: mem.Tile) void {
        for (0..8) |row| {
            const b0 = tile.plane0[row];
            const b1 = tile.plane1[row];

            for (0..8) |col| {
                const bit: u3 = @intCast(7 - col);
                const lo = (b0 >> bit) & 1;
                const hi = (b1 >> bit) & 1;
                const i: u8 = @intCast((hi << 1) | lo);

                const x = tile.x * 8 + col;
                const y = tile.y * 8 + row;
                const idx = (y * self.width + x) * 3;

                const rgb = palette[i * 3 ..];
                self.data[idx + 0] = rgb[0];
                self.data[idx + 1] = rgb[1];
                self.data[idx + 2] = rgb[2];
            }
        }
    }

    pub fn write(self: Buffer, name: []const u8) !void {
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

pub const palette = @embedFile("nes.pal");

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

    for (0..table.len / 16) |index| {
        const offset = index * 16;
        const tile = mem.Tile{
            .index = index,
            .x = (index % 16),
            .y = (index / 16),
            .plane0 = table[offset..][0..8],
            .plane1 = table[offset + 8 ..][0..8],
        };
        buffer.drawTile(tile);
    }
}

pub fn writeNameTable(ppu: mem.PPU) !void {
    const width = 256; // 32 tiles * 8
    const height = 240; // 30 tiles * 8

    var backing: [width * height * 3]u8 = undefined;
    var buffer = Buffer.init(&backing, width, height);

    fillNameBuffer(&buffer, ppu, 0, 0);
    try buffer.write("rom/nameTable0");

    if (!std.mem.eql(u8, ppu.nameTable0, ppu.nameTable1)) {
        fillNameBuffer(&buffer, ppu, 1, 0);
        try buffer.write("rom/nameTable1");
    }

    if (!std.mem.eql(u8, ppu.nameTable0, ppu.nameTable2)) {
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
            .x = index % 32,
            .y = index / 32,
            .plane0 = patternTable[offset..][0..8],
            .plane1 = patternTable[offset + 8 ..][0..8],
        };

        buffer.drawTile(tile);
    }
}
