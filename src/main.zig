const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const bytes = readFileAll(allocator, "rom/Feng Shen Bang.dmp");
    defer allocator.free(bytes);

    const ppuMemory = PPUMemory.init(bytes);

    printHex(ppuMemory.palette);
}

const PPUMemory = struct {
    // Pattern Tables
    patternTable0: []u8, // 0x0000 - 0x0FFF (4KB)
    patternTable1: []u8, // 0x1000 - 0x1FFF (4KB)

    // Name Tables
    nameTable0: []u8, // 0x2000 - 0x23FF
    nameTable1: []u8, // 0x2400 - 0x27FF
    nameTable2: []u8, // 0x2800 - 0x2BFF
    nameTable3: []u8, // 0x2C00 - 0x2FFF
    // Name Table mirror (0x3000 - 0x3EFF)
    nameTableMirror: []u8, // 0x3000 - 0x3EFF

    // palette
    palette: []u8, // 0x3F00 - 0x3F1F (32B)
    // palette mirror
    paletteMirror: []u8, // 0x3F20 - 0x3FFF

    pub fn init(bytes: []u8) PPUMemory {
        return .{
            .patternTable0 = bytes[0x0000..0x1000],
            .patternTable1 = bytes[0x1000..0x2000],

            .nameTable0 = bytes[0x2000..0x2400],
            .nameTable1 = bytes[0x2400..0x2800],
            .nameTable2 = bytes[0x2800..0x2C00],
            .nameTable3 = bytes[0x2C00..0x3000],

            .nameTableMirror = bytes[0x3000..0x3F00],

            .palette = bytes[0x3F00..0x3F20],
            .paletteMirror = bytes[0x3F20..0x4000],
        };
    }
};

fn readFileAll(allocator: std.mem.Allocator, path: []const u8) []u8 {
    var file = std.fs.cwd().openFile(path, .{}) catch @panic("open file failed");
    defer file.close();

    const bytes = file.readToEndAlloc(allocator, std.math.maxInt(usize));
    return bytes catch @panic("read file all failed");
}

pub fn printHex(hex: []const u8) void {
    for (hex, 0..) |value, i| {
        if (i % 16 == 0) {
            std.debug.print("\n{X:04}: ", .{i});
        }
        std.debug.print("{X:0>2} ", .{value});
    }
    std.debug.print("\n", .{});
}
