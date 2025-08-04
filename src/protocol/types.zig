//! Minecraft Protocol Data Types
const std = @import("std");

pub const VarInt = i32;

/// VarInt: Variable-length integer
/// Reads a VarInt from a reader. Returns the decoded integer and the number of bytes read.
pub fn readVarInt(reader: anytype) !struct { value: i32, bytes_read: u8 } {
    var value: i32 = 0;
    var bytes_read: u8 = 0;
    while (true) {
        const byte = reader.readByte() catch |err| {
            if (err == error.EndOfStream and bytes_read > 0) {
                // This is an incomplete VarInt, which is an error.
                return error.UnexpectedEof;
            }
            return err;
        };
        value |= @as(i32, byte & 0x7F) << @as(u5, @intCast(bytes_read * 7));
        bytes_read += 1;
        if (bytes_read > 5) {
            return error.VarIntTooLong;
        }
        if ((byte & 0x80) == 0) {
            break;
        }
    }
    return .{ .value = value, .bytes_read = bytes_read };
}

/// Writes a VarInt to a writer.
pub fn writeVarInt(writer: anytype, value: i32) !void {
    var val = @as(u32, @bitCast(value));
    while (true) {
        if ((val & ~@as(u32, 0x7F)) == 0) {
            try writer.writeByte(@as(u8, @intCast(val)));
            return;
        }
        try writer.writeByte(@as(u8, @intCast((val & 0x7F) | 0x80)));
        val >>= 7;
    }
}

/// String: Length-prefixed UTF-8 string
/// Reads a String from a reader.
pub fn readString(reader: anytype, allocator: std.mem.Allocator) ![]u8 {
    const len_info = try readVarInt(reader);
    const len = @as(usize, @intCast(len_info.value));
    const buffer = try allocator.alloc(u8, len);
    errdefer allocator.free(buffer);
    try reader.readNoEof(buffer);
    return buffer;
}

/// Writes a String to a writer.
pub fn writeString(writer: anytype, value: []const u8) !void {
    try writeVarInt(writer, @as(i32, @intCast(value.len)));
    try writer.writeAll(value);
}

/// Byte: i8
pub const Byte = i8;
/// Reads a Byte from a reader.
pub fn readByte(reader: anytype) !Byte {
    return reader.readInt(Byte, .big);
}
/// Writes a Byte to a writer.
pub fn writeByte(writer: anytype, value: Byte) !void {
    try writer.writeInt(Byte, value, .big);
}

/// Unsigned Byte: u8
pub const UByte = u8;
/// Reads an Unsigned Byte from a reader.
pub fn readUByte(reader: anytype) !UByte {
    return reader.readInt(UByte, .big);
}
/// Writes an Unsigned Byte to a writer.
pub fn writeUByte(writer: anytype, value: UByte) !void {
    try writer.writeInt(UByte, value, .big);
}

/// Short: i16 (big-endian)
pub const Short = i16;
/// Reads a Short from a reader.
pub fn readShort(reader: anytype) !Short {
    return reader.readInt(Short, .big);
}
/// Writes a Short to a writer.
pub fn writeShort(writer: anytype, value: Short) !void {
    try writer.writeInt(Short, value, .big);
}

// Unsigned Short: u16 (big-endian)
pub const UShort = u16;
pub fn readUShort(reader: anytype) !UShort {
    return reader.readInt(UShort, .big);
}
pub fn writeUShort(writer: anytype, value: UShort) !void {
    try writer.writeInt(UShort, value, .big);
}

// Int: i32 (big-endian)
pub const Int = i32;
pub fn readInt(reader: anytype) !Int {
    return reader.readInt(Int, .big);
}
pub fn writeInt(writer: anytype, value: Int) !void {
    try writer.writeInt(Int, value, .big);
}

// Long: i64 (big-endian)
pub const Long = i64;
pub fn readLong(reader: anytype) !Long {
    return reader.readInt(Long, .big);
}
pub fn writeLong(writer: anytype, value: Long) !void {
    try writer.writeInt(Long, value, .big);
}

// Float: f32 (big-endian)
pub const Float = f32;
pub fn readFloat(reader: anytype) !Float {
    return @bitCast(try reader.readInt(u32, .big));
}
pub fn writeFloat(writer: anytype, value: Float) !void {
    try writer.writeInt(u32, @bitCast(value), .big);
}

// Double: f64 (big-endian)
pub const Double = f64;
pub fn readDouble(reader: anytype) !Double {
    return @bitCast(try reader.readInt(u64, .big));
}
pub fn writeDouble(writer: anytype, value: Double) !void {
    try writer.writeInt(u64, @bitCast(value), .big);
}

// Boolean: bool (1 byte)
pub const Boolean = bool;
pub fn readBoolean(reader: anytype) !Boolean {
    return (try reader.readByte()) != 0;
}
pub fn writeBoolean(writer: anytype, value: Boolean) !void {
    try writer.writeByte(if (value) 1 else 0);
}

// Position: i64 (encoded)
pub const Position = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn read(reader: anytype) !Position {
        const val = try readLong(reader);
        var x = @as(i32, @intCast(val >> 38));
        var y = @as(i32, @intCast((val >> 26) & 0xFFF));
        var z = @as(i32, @intCast(val & 0x3FFFFFF));

        // Sign extension
        if (x >= 1 << 25) x -= 1 << 26;
        if (y >= 1 << 11) y -= 1 << 12;
        if (z >= 1 << 25) z -= 1 << 26;

        return .{ .x = x, .y = y, .z = z };
    }

    pub fn write(writer: anytype, pos: Position) !void {
        const val = (@as(u64, @bitCast(pos.x)) & 0x3FFFFFF) << 38 |
            (@as(u64, @bitCast(pos.y)) & 0xFFF) << 26 |
            (@as(u64, @bitCast(pos.z)) & 0x3FFFFFF);
        try writeLong(writer, @as(i64, @bitCast(val)));
    }
};

// UUID: [16]u8
pub const UUID = [16]u8;
pub fn readUUID(reader: anytype) !UUID {
    var uuid: UUID = undefined;
    try reader.readNoEof(&uuid);
    return uuid;
}
pub fn writeUUID(writer: anytype, uuid: UUID) !void {
    try writer.writeAll(&uuid);
}

// Chat: JSON String (represented as a String type)
pub const Chat = []u8;
pub fn readChat(reader: anytype, allocator: std.mem.Allocator) !Chat {
    return readString(reader, allocator);
}
pub fn writeChat(writer: anytype, chat: Chat) !void {
    try writeString(writer, chat);
}

// NBT Tag: Placeholder
pub const NBTTag = struct {
    pub fn read(reader: anytype, allocator: std.mem.Allocator) !void {
        _ = allocator;
        const tag_id = try readByte(reader);
        if (tag_id != 0) {
            return error.NBTNotImplemented;
        }
    }

    pub fn write(writer: anytype) !void {
        try writeByte(writer, 0); // TAG_End
    }
};

// Item Slot: Placeholder
pub const ItemSlot = struct {
    item_id: Short,

    pub fn read(reader: anytype) !ItemSlot {
        const item_id = try readShort(reader);
        if (item_id != -1) {
            _ = try readByte(reader); // Item Count
            _ = try readShort(reader); // Item Damage
            try NBTTag.read(reader, std.heap.page_allocator); // NBT Data
        }
        return .{ .item_id = item_id };
    }

    pub fn write(writer: anytype, item: ItemSlot) !void {
        try writeShort(writer, item.item_id);
        if (item.item_id != -1) {
            try writeByte(writer, 1); // Item Count
            try writeShort(writer, 0); // Item Damage
            try NBTTag.write(writer); // NBT Data
        }
    }
};

// Metadata: Placeholder
pub const Metadata = struct {
    pub fn read(reader: anytype, allocator: std.mem.Allocator) !void {
        _ = allocator;
        while (true) {
            const item = try readUByte(reader);
            if (item == 0x7F) break;
            // Skip remaining data for now
        }
    }

    pub fn write(writer: anytype) !void {
        try writeUByte(writer, 0x7F); // End of metadata
    }
};

// Angle: u8 (angle * 256 / 360)
pub const Angle = u8;

pub const VarIntTooLong = error.VarIntTooLong;
pub const NotImplemented = error.NotImplemented;
