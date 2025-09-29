const std = @import("std");

const mem = @import("memory.zig");

pub const Buffer = struct {
    data: []u8, // 长度 = width * height * 3
    width: usize,
    height: usize,

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

                const x = tile.x + col;
                const y = tile.y + row;
                const idx = (y * self.width + x) * 3;

                const rgb = PALETTE[i];
                self.data[idx + 0] = rgb[0];
                self.data[idx + 1] = rgb[1];
                self.data[idx + 2] = rgb[2];
            }
        }
    }

    pub fn write(self: Buffer, path: []const u8) !void {
        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writer().print("P6\n{} {}\n255\n", .{
            self.width,
            self.height,
        });
        try file.writeAll(self.data);
    }
};

const PALETTE: [4][3]u8 = .{
    .{ 0, 0, 0 },
    .{ 85, 85, 85 },
    .{ 170, 170, 170 },
    .{ 255, 255, 255 },
};

pub fn writePatternTable(path: []const u8, table: []const u8) !void {
    const width = 128;
    const height = 128;

    var backing: [width * height * 3]u8 = undefined;
    var buffer = Buffer.init(&backing, width, height);

    for (0..table.len / 16) |index| {
        const base = index * 16;
        const tile = mem.Tile{
            .x = (index % 16) * 8,
            .y = (index / 16) * 8,
            .plane0 = table[base .. base + 8],
            .plane1 = table[base + 8 .. base + 16],
        };
        buffer.drawTile(tile);
    }

    try buffer.write(path);
}

const str = []const u8;
pub fn writeNameTable(path: str, nameTable: str, patternTable: str) !void {
    const width = 256; // 32 tiles * 8
    const height = 240; // 30 tiles * 8

    var backing: [width * height * 3]u8 = undefined;
    var buf = Buffer.init(&backing, width, height);

    for (0..960) |i| {
        const tileIndex: usize = nameTable[i];
        const base = tileIndex * 16;

        const tile = mem.Tile{
            .x = (i % 32) * 8,
            .y = (i / 32) * 8,
            .plane0 = patternTable[base .. base + 8],
            .plane1 = patternTable[base + 8 .. base + 16],
        };

        buf.drawTile(tile);
    }

    try buf.write(path);
}
