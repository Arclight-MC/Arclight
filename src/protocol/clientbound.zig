const std = @import("std");
const types = @import("types.zig");
const world = @import("../world/world.zig");
const ArrayList = std.ArrayList(u8);

pub const StatusResponse = struct {
    json_response: []const u8,

    pub fn write(writer: anytype, response: StatusResponse, allocator: std.mem.Allocator) !void {
        var buffer = try ArrayList.initCapacity(allocator, 256);
        defer buffer.deinit(allocator);
        const temp_writer = buffer.writer(allocator);

        try types.writeVarInt(temp_writer, 0x00);
        try types.writeString(temp_writer, response.json_response);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const Pong = struct {
    payload: types.Long,

    pub fn write(writer: anytype, pong: Pong) !void {
        var buffer: ArrayList = .empty;
        const temp_writer = buffer.writer(std.heap.page_allocator);

        try types.writeVarInt(temp_writer, 0x01); // Packet ID
        try types.writeLong(temp_writer, pong.payload);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const LoginDisconnect = struct {
    reason: []const u8,

    pub fn write(writer: anytype, packet: LoginDisconnect) !void {
        var buffer: ArrayList = .empty;
        const temp_writer = buffer.writer(std.heap.page_allocator);

        try types.writeVarInt(temp_writer, 0x00);
        try types.writeString(temp_writer, packet.reason);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const EncryptionRequest = struct {
    server_id: []const u8,
    public_key: []const u8,
    verify_token: []const u8,

    pub fn write(writer: anytype, packet: EncryptionRequest, allocator: std.mem.Allocator) !void {
        var buffer = try ArrayList.initCapacity(allocator, 256);
        defer buffer.deinit(allocator);
        const temp_writer = buffer.writer(allocator);

        try types.writeVarInt(temp_writer, 0x01);
        try types.writeString(temp_writer, packet.server_id);
        try types.writeVarInt(temp_writer, @as(i32, @intCast(packet.public_key.len)));
        try temp_writer.writeAll(packet.public_key);
        try types.writeVarInt(temp_writer, @as(i32, @intCast(packet.verify_token.len)));
        try temp_writer.writeAll(packet.verify_token);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const LoginSuccess = struct {
    uuid: []const u8,
    username: []const u8,

    pub fn write(writer: anytype, login_success: LoginSuccess, allocator: std.mem.Allocator) !void {
        var buffer = try ArrayList.initCapacity(allocator, 128);
        defer buffer.deinit(allocator);
        const temp_writer = buffer.writer(allocator);

        try types.writeVarInt(temp_writer, 0x02); // Packet ID
        try types.writeString(temp_writer, login_success.uuid);
        try types.writeString(temp_writer, login_success.username);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const SetCompression = struct {
    threshold: types.VarInt,

    pub fn write(writer: anytype, packet: SetCompression, allocator: std.mem.Allocator) !void {
        var buffer = try ArrayList.initCapacity(allocator, 64);
        defer buffer.deinit(allocator);
        const temp_writer = buffer.writer(allocator);

        try types.writeVarInt(temp_writer, 0x03);
        try types.writeVarInt(temp_writer, packet.threshold);

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
        var buffer = try ArrayList.initCapacity(allocator, 128);
        defer buffer.deinit(allocator);
        const temp_writer = buffer.writer(allocator);

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
        var buffer = try ArrayList.initCapacity(allocator, 128);
        defer buffer.deinit(allocator);
        const temp_writer = buffer.writer(allocator);

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
        var buffer = try ArrayList.initCapacity(allocator, 64);
        defer buffer.deinit(allocator);
        const temp_writer = buffer.writer(allocator);

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

    pub fn init(allocator: std.mem.Allocator, chunk_x: i32, chunk_z: i32, w: *?world.World) !ChunkData {
        const world_ptr = &w.*.?;
        const chunk = try world_ptr.getChunk(chunk_x, chunk_z);

        var chunk_data = try ArrayList.initCapacity(allocator, 8192);
        errdefer chunk_data.deinit(allocator);
        const writer = chunk_data.writer(allocator);

        var sections_sent: u16 = 0;

        for (0..16) |section_y| {
            var has_blocks = false;
            for (0..16) |x| {
                for (0..16) |z| {
                    const block = chunk.getBlock(x, section_y * 16, z);
                    if (block.id != 0) {
                        has_blocks = true;
                        break;
                    }
                }
                if (has_blocks) break;
            }

            if (!has_blocks) {
                try writer.writeByte(0);
                continue;
            }

            const section_mask: u16 = switch (section_y) {
                0 => 0x0001,
                1 => 0x0002,
                2 => 0x0004,
                3 => 0x0008,
                4 => 0x0010,
                5 => 0x0020,
                6 => 0x0040,
                7 => 0x0080,
                8 => 0x0100,
                9 => 0x0200,
                10 => 0x0400,
                11 => 0x0800,
                12 => 0x1000,
                13 => 0x2000,
                14 => 0x4000,
                15 => 0x8000,
                else => 0,
            };
            sections_sent |= section_mask;

            try writer.writeByte(0);

            for (0..16) |x| {
                for (0..16) |z| {
                    for (0..16) |y| {
                        const block = chunk.getBlock(x, section_y * 16 + y, z);
                        try writer.writeByte(block.id);
                    }
                }
            }

            for (0..16) |x| {
                for (0..16) |z| {
                    for (0..16) |y| {
                        const block = chunk.getBlock(x, section_y * 16 + y, z);
                        try writer.writeByte(block.metadata);
                    }
                }
            }

            var light_data = [_]u8{0xFF} ** 2048;
            try writer.writeAll(&light_data);
        }

        const primary_bit_mask = sections_sent;

        return ChunkData{
            .chunk_x = chunk_x,
            .chunk_z = chunk_z,
            .ground_up_continuous = true,
            .primary_bit_mask = primary_bit_mask,
            .data = try chunk_data.toOwnedSlice(allocator),
        };
    }

    pub fn write(self: ChunkData, writer: anytype, allocator: std.mem.Allocator) !void {
        var buffer = try ArrayList.initCapacity(allocator, 256);
        defer buffer.deinit(allocator);
        const temp_writer = buffer.writer(allocator);

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

pub const SpawnPlayer = struct {
    entity_id: types.VarInt,
    player_uuid: types.UUID,
    x: i32,
    y: i32,
    z: i32,
    yaw: u8,
    pitch: u8,
    current_item: i16,
    metadata: []const u8, // TODO: implement metadata type

    pub fn write(writer: anytype, packet: SpawnPlayer, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x0C);
        try types.writeVarInt(temp_writer, packet.entity_id);
        try types.writeUUID(temp_writer, packet.player_uuid);
        try types.writeInt(temp_writer, packet.x);
        try types.writeInt(temp_writer, packet.y);
        try types.writeInt(temp_writer, packet.z);
        try types.writeUByte(temp_writer, packet.yaw);
        try types.writeUByte(temp_writer, packet.pitch);
        try types.writeShort(temp_writer, packet.current_item);
        try temp_writer.writeAll(packet.metadata);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const DestroyEntities = struct {
    entity_ids: []const types.VarInt,

    pub fn write(writer: anytype, packet: DestroyEntities, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x13);
        try types.writeVarInt(temp_writer, @intCast(packet.entity_ids.len));
        for (packet.entity_ids) |entity_id| {
            try types.writeVarInt(temp_writer, entity_id);
        }

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const EntityTeleport = struct {
    entity_id: types.VarInt,
    x: i32,
    y: i32,
    z: i32,
    yaw: u8,
    pitch: u8,
    on_ground: bool,

    pub fn write(writer: anytype, packet: EntityTeleport, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x18);
        try types.writeVarInt(temp_writer, packet.entity_id);
        try types.writeInt(temp_writer, packet.x);
        try types.writeInt(temp_writer, packet.y);
        try types.writeInt(temp_writer, packet.z);
        try types.writeUByte(temp_writer, packet.yaw);
        try types.writeUByte(temp_writer, packet.pitch);
        try types.writeBoolean(temp_writer, packet.on_ground);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const PlayerListItem = struct {
    action: types.VarInt,
    players: []const Player,

    pub const Player = struct {
        uuid: types.UUID,
        name: []const u8,
        properties: []const Property,
        gamemode: types.VarInt,
        ping: types.VarInt,
        has_display_name: bool,
        display_name: ?[]const u8,
    };

    pub const Property = struct {
        name: []const u8,
        value: []const u8,
        is_signed: bool,
        signature: ?[]const u8,
    };

    pub fn write(writer: anytype, packet: PlayerListItem, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x38);
        try types.writeVarInt(temp_writer, packet.action);
        try types.writeVarInt(temp_writer, @intCast(packet.players.len));

        for (packet.players) |player| {
            try types.writeUUID(temp_writer, player.uuid);
            switch (packet.action) {
                0 => { // add player
                    try types.writeString(temp_writer, player.name);
                    try types.writeVarInt(temp_writer, @intCast(player.properties.len));
                    for (player.properties) |prop| {
                        try types.writeString(temp_writer, prop.name);
                        try types.writeString(temp_writer, prop.value);
                        try types.writeBoolean(temp_writer, prop.is_signed);
                        if (prop.is_signed) {
                            try types.writeString(temp_writer, prop.signature.?);
                        }
                    }
                    try types.writeVarInt(temp_writer, player.gamemode);
                    try types.writeVarInt(temp_writer, player.ping);
                    try types.writeBoolean(temp_writer, player.has_display_name);
                    if (player.has_display_name) {
                        try types.writeString(temp_writer, player.display_name.?);
                    }
                },
                1 => { // update gamemode
                    try types.writeVarInt(temp_writer, player.gamemode);
                },
                2 => { // update latency
                    try types.writeVarInt(temp_writer, player.ping);
                },
                3 => { // update display name
                    try types.writeBoolean(temp_writer, player.has_display_name);
                    if (player.has_display_name) {
                        try types.writeString(temp_writer, player.display_name.?);
                    }
                },
                4 => {}, // remove player
                else => return error.InvalidPacketData,
            }
        }

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const EntityEquipment = struct {
    entity_id: types.VarInt,
    slot: i16,
    item: types.ItemSlot,

    pub fn write(writer: anytype, packet: EntityEquipment, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x04);
        try types.writeVarInt(temp_writer, packet.entity_id);
        try types.writeShort(temp_writer, packet.slot);
        try packet.item.write(temp_writer);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const SpawnPosition = struct {
    location: types.Position,

    pub fn write(writer: anytype, packet: SpawnPosition, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x05);
        try packet.location.write(temp_writer);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const UpdateHealth = struct {
    health: f32,
    food: types.VarInt,
    food_saturation: f32,

    pub fn write(writer: anytype, packet: UpdateHealth, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x06);
        try types.writeFloat(temp_writer, packet.health);
        try types.writeVarInt(temp_writer, packet.food);
        try types.writeFloat(temp_writer, packet.food_saturation);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const Respawn = struct {
    dimension: i32,
    difficulty: u8,
    gamemode: u8,
    level_type: []const u8,

    pub fn write(writer: anytype, packet: Respawn, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x07);
        try types.writeInt(temp_writer, packet.dimension);
        try types.writeUByte(temp_writer, packet.difficulty);
        try types.writeUByte(temp_writer, packet.gamemode);
        try types.writeString(temp_writer, packet.level_type);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const HeldItemChange = struct {
    slot: i8,

    pub fn write(writer: anytype, packet: HeldItemChange, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x09);
        try types.writeByte(temp_writer, packet.slot);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const Animation = struct {
    entity_id: types.VarInt,
    animation_id: u8,

    pub fn write(writer: anytype, packet: Animation, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x0B);
        try types.writeVarInt(temp_writer, packet.entity_id);
        try types.writeUByte(temp_writer, packet.animation_id);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const SpawnObject = struct {
    entity_id: types.VarInt,
    type: u8,
    x: i32,
    y: i32,
    z: i32,
    pitch: u8,
    yaw: u8,
    data: i32,
    velocity_x: ?i16,
    velocity_y: ?i16,
    velocity_z: ?i16,

    pub fn write(writer: anytype, packet: SpawnObject, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x0E);
        try types.writeVarInt(temp_writer, packet.entity_id);
        try types.writeUByte(temp_writer, packet.type);
        try types.writeInt(temp_writer, packet.x);
        try types.writeInt(temp_writer, packet.y);
        try types.writeInt(temp_writer, packet.z);
        try types.writeUByte(temp_writer, packet.pitch);
        try types.writeUByte(temp_writer, packet.yaw);
        try types.writeInt(temp_writer, packet.data);

        if (packet.data > 0) {
            try types.writeShort(temp_writer, packet.velocity_x.?);
            try types.writeShort(temp_writer, packet.velocity_y.?);
            try types.writeShort(temp_writer, packet.velocity_z.?);
        }

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const SpawnMob = struct {
    entity_id: types.VarInt,
    type: u8,
    x: i32,
    y: i32,
    z: i32,
    yaw: u8,
    pitch: u8,
    head_pitch: u8,
    velocity_x: i16,
    velocity_y: i16,
    velocity_z: i16,
    metadata: []const u8, // TODO: implement metadata type

    pub fn write(writer: anytype, packet: SpawnMob, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x0F);
        try types.writeVarInt(temp_writer, packet.entity_id);
        try types.writeUByte(temp_writer, packet.type);
        try types.writeInt(temp_writer, packet.x);
        try types.writeInt(temp_writer, packet.y);
        try types.writeInt(temp_writer, packet.z);
        try types.writeUByte(temp_writer, packet.yaw);
        try types.writeUByte(temp_writer, packet.pitch);
        try types.writeUByte(temp_writer, packet.head_pitch);
        try types.writeShort(temp_writer, packet.velocity_x);
        try types.writeShort(temp_writer, packet.velocity_y);
        try types.writeShort(temp_writer, packet.velocity_z);
        try temp_writer.writeAll(packet.metadata);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const TimeUpdate = struct {
    world_age: types.Long,
    time_of_day: types.Long,

    pub fn write(writer: anytype, packet: TimeUpdate, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x03); // Packet ID
        try types.writeLong(temp_writer, packet.world_age);
        try types.writeLong(temp_writer, packet.time_of_day);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};

pub const ChatMessage = struct {
    json_data: []const u8,
    position: i8,

    pub fn write(writer: anytype, packet: ChatMessage, allocator: std.mem.Allocator) !void {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        try types.writeVarInt(temp_writer, 0x02); // Packet ID
        try types.writeString(temp_writer, packet.json_data);
        try types.writeByte(temp_writer, packet.position);

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
};
