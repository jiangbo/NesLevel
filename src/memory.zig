const std = @import("std");

pub const Tile = struct {
    x: usize,
    y: usize,
    plane0: []const u8, // 8 字节
    plane1: []const u8, // 8 字节
};

pub const PPU = struct {
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

    pub fn init(rom: []u8) PPU {
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
