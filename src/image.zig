const std = @import("std");

pub const Buffer = struct {
    width: usize,
    height: usize,
    data: []const u8,

    pub fn init(width: usize, height: usize, data: []const u8) Buffer {
        std.debug.assert(data.len == width * height * 3);
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
};
