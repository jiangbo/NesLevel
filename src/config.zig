const std = @import("std");

pub const tileSize = 8; // 每个 tile 8x8
pub const pixelSize = 3; // 每个像素 3 个字节
pub const bytePerTileRow = tileSize * pixelSize;
pub const bytePerTileCol = bytePerTileRow;
pub const bytePerTileCell = bytePerTileRow * tileSize;
pub const tilePerBank = 256; // 每个 bank 256 个 tile
pub const bytePerBank = bytePerTileCell * tilePerBank;
pub const tilePerRow = 16; // 每行 16 个 tile
pub const bytePerRow = bytePerTileRow * tilePerRow;
pub const pixelPerRow = tilePerRow * tileSize;

pub const nameTableCols = 32;
pub const nameTableRows = 30;
