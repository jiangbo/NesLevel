const std = @import("std");

const mem = @import("memory.zig");

pub const Buffer = struct {
    data: []u8,
    width: usize,
    height: usize,

    pub fn init(data: []u8, width: usize, height: usize) Buffer {
        std.debug.assert(data.len == width * height);
        return Buffer{ .data = data, .width = width, .height = height };
    }

    fn drawTile(self: *Buffer, tile: mem.Tile) void {
        const gray: [4]u8 = .{ 0, 85, 170, 255 };

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
                self.data[y * self.width + x] = gray[i];
            }
        }
    }

    pub fn write(self: Buffer, name: []const u8) !void {
        var buffer: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&buffer, "{s}.pgm", .{name});
        var file = try std.fs.cwd().createFile(path, .{});

        defer file.close();

        try file.writer().print("P5\n{} {}\n255\n", .{
            self.width,
            self.height,
        });
        try file.writeAll(self.data);
    }
};

pub fn writePatternTable(path: []const u8, table: []const u8) !void {
    const width = 128;
    const height = 128;

    var backing: [width * height]u8 = undefined;
    var buffer = Buffer.init(&backing, width, height);

    for (0..table.len / 16) |index| {
        const offset = index * 16;
        const tile = mem.Tile{
            .index = index,
            .x = (index % 16) * 8,
            .y = (index / 16) * 8,
            .plane0 = table[offset..][0..8],
            .plane1 = table[offset + 8 ..][0..8],
        };
        buffer.drawTile(tile);
    }

    try buffer.write(path);
}

const str = []const u8;
pub fn writeNameTable(path: str, nameTable: str, patternTable: str) !void {
    const width = 256; // 32 tiles * 8
    const height = 240; // 30 tiles * 8

    var backing: [width * height]u8 = undefined;
    var buf = Buffer.init(&backing, width, height);

    for (0..960) |index| {
        const offset = @as(usize, nameTable[index]) * 16;
        const tile = mem.Tile{
            .index = nameTable[index],
            .x = (index % 32) * 8,
            .y = (index / 32) * 8,
            .plane0 = patternTable[offset..][0..8],
            .plane1 = patternTable[offset + 8 ..][0..8],
        };

        buf.drawTile(tile);
    }

    try buf.write(path);
}
