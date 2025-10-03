const std = @import("std");

const cfg = @import("config.zig");

pub const Buffer = struct {
    width: usize,
    height: usize,
    data: []u8,

    pub fn init(width: usize, height: usize, data: []u8) Buffer {
        std.debug.assert(data.len == width * height * cfg.pixelSize);
        return Buffer{ .width = width, .height = height, .data = data };
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

    pub fn draw8x8Grid(self: *Buffer) void {
        self.drawGrid(8);
    }

    pub fn draw16x16Grid(self: *Buffer) void {
        self.drawGrid(16);
    }

    pub fn draw32x32Grid(self: *Buffer) void {
        self.drawGrid(32);
    }

    pub fn drawGrid(self: *Buffer, step: usize) void {
        const pixel_size = cfg.pixelSize; // 应该是 3
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                if (x % step == 0 or y % step == 0) {
                    const idx = (y * self.width + x) * pixel_size;
                    // 写绿色
                    self.data[idx + 0] = 0;
                    self.data[idx + 1] = 255;
                    self.data[idx + 2] = 0;
                }
            }
        }
    }
};
