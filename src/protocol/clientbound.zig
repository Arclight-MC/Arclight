const std = @import("std");
const types = @import("types.zig");

pub const StatusResponse = struct {
    json_response: []const u8,

    pub fn write(writer: anytype, response: StatusResponse, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x00); // Packet ID
        try types.writeString(temp_writer, response.json_response);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const Pong = struct {
    payload: types.Long,

    pub fn write(writer: anytype, pong: Pong) !void {
        var buffer = std.ArrayList(u8).init(std.heap.page_allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x01); // Packet ID
        try types.writeLong(temp_writer, pong.payload);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const LoginSuccess = struct {
    uuid: []const u8,
    username: []const u8,

    pub fn write(writer: anytype, login_success: LoginSuccess, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x02); // Packet ID
        try types.writeString(temp_writer, login_success.uuid);
        try types.writeString(temp_writer, login_success.username);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const JoinGame = struct {
    entity_id: i32,
    gamemode: u8,
    dimension: i8,
    difficulty: u8,
    max_players: u8,
    level_type: []const u8,
    reduced_debug_info: bool,

    pub fn write(writer: anytype, join_game: JoinGame, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x01); // Packet ID for JoinGame
        try types.writeInt(temp_writer, join_game.entity_id);
        try types.writeUByte(temp_writer, join_game.gamemode);
        try types.writeByte(temp_writer, join_game.dimension);
        try types.writeUByte(temp_writer, join_game.difficulty);
        try types.writeUByte(temp_writer, join_game.max_players);
        try types.writeString(temp_writer, join_game.level_type);
        try types.writeBoolean(temp_writer, join_game.reduced_debug_info);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const PlayerPositionAndLook = struct {
    x: f64,
    y: f64,
    z: f64,
    yaw: f32,
    pitch: f32,
    flags: u8,

    pub fn write(writer: anytype, pos_look: PlayerPositionAndLook, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x08); // Packet ID for PlayerPositionAndLook
        try types.writeDouble(temp_writer, pos_look.x);
        try types.writeDouble(temp_writer, pos_look.y);
        try types.writeDouble(temp_writer, pos_look.z);
        try types.writeFloat(temp_writer, pos_look.yaw);
        try types.writeFloat(temp_writer, pos_look.pitch);
        try types.writeUByte(temp_writer, pos_look.flags);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const KeepAlive = struct {
    keep_alive_id: i32,

    pub fn write(writer: anytype, keep_alive: KeepAlive, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x00); // Packet ID
        try types.writeVarInt(temp_writer, keep_alive.keep_alive_id);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const ChunkData = struct {
    chunk_x: i32,
    chunk_z: i32,
    ground_up_continuous: bool,
    primary_bit_mask: u16,
    data: []const u8,

    pub fn init(allocator: std.mem.Allocator, chunk_x: i32, chunk_z: i32) !ChunkData {
        // For now, create a simple flat chunk of grass
        var chunk_data = std.ArrayList(u8).init(allocator);
        const writer = chunk_data.writer();

        // 16x16x16 section
        const block_id = (2 << 4) | 0; // Grass
        var i: usize = 0;
        while (i < 4096) : (i += 1) {
            try writer.writeInt(u16, block_id, .big);
        }
        // Light data (dummy)
        i = 0;
        while (i < 2048) : (i += 1) {
            try writer.writeByte(0xFF);
        }
        // Sky light data (dummy)
        i = 0;
        while (i < 2048) : (i += 1) {
            try writer.writeByte(0xFF);
        }

        return ChunkData{
            .chunk_x = chunk_x,
            .chunk_z = chunk_z,
            .ground_up_continuous = true,
            .primary_bit_mask = 0x0001, // Only the first section
            .data = try chunk_data.toOwnedSlice(),
        };
    }

    pub fn write(self: ChunkData, writer: anytype, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x21); // Packet ID
        try types.writeInt(temp_writer, self.chunk_x);
        try types.writeInt(temp_writer, self.chunk_z);
        try types.writeBoolean(temp_writer, self.ground_up_continuous);
        try types.writeUShort(temp_writer, self.primary_bit_mask);
        try types.writeVarInt(temp_writer, @as(i32, @intCast(self.data.len)));
        try temp_writer.writeAll(self.data);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};