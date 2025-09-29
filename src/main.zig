const std = @import("std");

const pgm = @import("ppm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const rom = try readFileAll(allocator, "rom/Feng Shen Bang.dmp");
    defer allocator.free(rom);

    const ppuMemory = PPUMemory.init(rom);

    printHex(ppuMemory.attributeTable);

    try pgm.writePatternTable("rom/pattern0.pgm", ppuMemory.patternTable0);
    try pgm.writePatternTable("rom/pattern1.pgm", ppuMemory.patternTable1);

    try pgm.writeNameTable("rom/nameTable0.pgm", ppuMemory.nameTable0, ppuMemory.patternTable0);

    if (!std.mem.eql(u8, ppuMemory.nameTable0, ppuMemory.nameTable1)) {
        try pgm.writeNameTable("rom/nameTable1.pgm", ppuMemory.nameTable1, ppuMemory.patternTable0);
    }

    if (!std.mem.eql(u8, ppuMemory.nameTable0, ppuMemory.nameTable2)) {
        try pgm.writeNameTable("rom/nameTable2.pgm", ppuMemory.nameTable2, ppuMemory.patternTable0);
    }
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

    pub fn init(rom: []u8) PPUMemory {
        return .{
            .patternTable0 = rom[0x0000..0x1000],
            .patternTable1 = rom[0x1000..0x2000],

            .nameTable0 = rom[0x2000..0x2400],
            .nameTable1 = rom[0x2400..0x2800],
            .nameTable2 = rom[0x2800..0x2C00],
            .nameTable3 = rom[0x2C00..0x3000],

            .nameTableMirror = rom[0x3000..0x3F00],

            .attributeTable = rom[0x3F00..0x3F20],
            .attributeTableMirror = rom[0x3F20..0x4000],
        };
    }
};

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
