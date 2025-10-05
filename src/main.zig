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

    ctx.palette = ppu.palette;
    try pgm.writePatternTable(ppu);
    try pgm.writeNameTable(ppu);

    try ppm.writePatternTable(ppu);
    try ppm.writeNameTable(ppu);

    try ctx.writeAllTiles();

    try ctx.extract2x2Blocks(ppu.nameTable0);
    try ctx.extract2x2Blocks(ppu.nameTable2);

    const blockNumber: usize = 112;
    try block.write4x1(allocator, rom[0x38110..][0..blockNumber]);

    try block.writeSetBlock(allocator, ctx.block2x2Set);

    block.findBlock(rom, ctx.block2x2Set);

    ctx.blockAttributes = rom[0x38510..][0..blockNumber];
    ctx.patternTable = ppu.patternTable0;
    ctx.blockDef = rom[0x38110..][0 .. blockNumber * 4];
    std.log.info("block def len: {}", .{ctx.blockDef.len});
    try block.writeAttributeBlock(allocator, ctx.blockDef);

    var level = rom[0x38800..][0..480];
    const buffer = try allocator.alloc(u8, level.len * 2);
    defer allocator.free(buffer);
    const half = @divExact(level.len, 2);
    interCopy(buffer, level[0..half], level[half..]);

    level = rom[0x39520..][0..480];
    interCopy(buffer[level.len..], level[0..half], level[half..]);

    try block.writeLevel(allocator, .{
        .blockIndexes = buffer,
        .widthBlock = 32,
        .heightBlock = @divExact(buffer.len, 32),
        .tilePerRow = 32 * 2,
    });

    // try block.write2x2(allocator, ppu);
    // try block.write4x4(allocator, ppu);
}

fn readFileAll(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

fn interCopy(buffer: []u8, s1: []const u8, s2: []const u8) void {
    std.debug.assert(s1.len == s2.len);
    const chunk = 16;
    const count = @divExact(s1.len, chunk);

    for (0..count) |index| {
        const srcIndex = index * chunk;
        var dstIndex = index * chunk * 2;

        @memcpy(buffer[dstIndex..][0..chunk], s1[srcIndex..][0..chunk]);
        dstIndex += chunk;
        @memcpy(buffer[dstIndex..][0..chunk], s2[srcIndex..][0..chunk]);
    }
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
