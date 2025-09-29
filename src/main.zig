const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const bytes = try readFileAll(allocator, "rom/Feng Shen Bang.dmp");
    defer allocator.free(bytes);

    const ppuMemory = PPUMemory.init(bytes);

    printHex(ppuMemory.attributeTable);

    try writePatternTablePGM("rom/pattern0.pgm", ppuMemory.patternTable0);
    try writePatternTablePGM("rom/pattern1.pgm", ppuMemory.patternTable1);
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

    // attribute Tables
    attributeTable: []u8, // 0x3F00 - 0x3F1F (32B)
    // palette mirror
    attributeTableMirror: []u8, // 0x3F20 - 0x3FFF

    pub fn init(bytes: []u8) PPUMemory {
        return .{
            .patternTable0 = bytes[0x0000..0x1000],
            .patternTable1 = bytes[0x1000..0x2000],

            .nameTable0 = bytes[0x2000..0x2400],
            .nameTable1 = bytes[0x2400..0x2800],
            .nameTable2 = bytes[0x2800..0x2C00],
            .nameTable3 = bytes[0x2C00..0x3000],

            .nameTableMirror = bytes[0x3000..0x3F00],

            .attributeTable = bytes[0x3F00..0x3F20],
            .attributeTableMirror = bytes[0x3F20..0x4000],
        };
    }
};

fn writePatternTablePGM(path: []const u8, table: []const u8) !void {
    const width = 128;
    const height = 128;

    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writer().print("P5\n{} {}\n255\n", .{ width, height });

    var buffer: [width * height]u8 = undefined;

    for (0..table.len / 16) |index| {
        const x = (index % 16) * 8;
        const y = (index / 16) * 8;

        const plane0 = table[index * 16 ..][0..8];
        const plane1 = table[index * 16 + 8 ..][0..8];

        for (0..8) |row| {
            const b0 = plane0[row];
            const b1 = plane1[row];

            for (0..8) |col| {
                const bit: u3 = @intCast(7 - col);
                const lo = (b0 >> bit) & 1;
                const hi = (b1 >> bit) & 1;
                const i: u8 = @intCast((hi << 1) | lo);

                const gray: [4]u8 = .{ 0, 85, 170, 255 };
                buffer[(y + row) * width + (x + col)] = gray[i];
            }
        }
    }

    try file.writeAll(&buffer);
}

fn readFileAll(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return file.readToEndAlloc(allocator, std.math.maxInt(usize));
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
