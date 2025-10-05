const std = @import("std");

const ctx = @import("context.zig");
const mem = @import("memory.zig");
const block = @import("block.zig");
const pgm = @import("pgm.zig");
const ppm = @import("ppm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const ppuDump = try readFileAll(allocator, "rom/Feng Shen Bang.dmp");
    defer allocator.free(ppuDump);

    const rom = try readFileAll(allocator, "rom/Feng Shen Bang.nes");
    defer allocator.free(rom);

    ctx.init(allocator);
    defer ctx.deinit();

    const ppu = mem.PPU.init(ppuDump);
    printHex(ppu.palette);
    printHex(ppu.nameTable0[mem.PPU.attrIndex..]);
    printHex(ppu.nameTable2[mem.PPU.attrIndex..]);

    try pgm.writePatternTable(ppu);
    try pgm.writeNameTable(ppu);

    try ppm.writePatternTable(ppu);
    try ppm.writeNameTable(ppu);

    // try ctx.writeAllTiles();

    try ctx.extract2x2Blocks(ppu.nameTable0);
    try ctx.extract2x2Blocks(ppu.nameTable2);

    // const key: u32 = 0xD7D6D7D6;
    // const key: u32 = 0xD6D7D6D7;
    // const key: u32 = 0xE6E7D8D9;
    const key: u32 = 0xD9D8E7E6;
    const v = ctx.block2x2Set.get(key);
    std.log.info("first color: {?b}", .{v});
    try block.write4x1(allocator, rom[0x38110..][0..256]);

    try block.writeSetBlock(allocator, ctx.block2x2Set);

    block.findBlock(rom, ctx.block2x2Set);

    // try block.write2x2(allocator, ppu);
    // try block.write4x4(allocator, ppu);
}

fn readFileAll(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

fn printHex(hex: []const u8) void {
    for (hex, 0..) |value, i| {
        if (i % 16 == 0) {
            std.debug.print("\n{X:04}: ", .{i});
        }
        std.debug.print("{X:0>2} ", .{value});
    }
    std.debug.print("\n", .{});
}
