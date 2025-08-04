const std = @import("std");
const types = @import("types.zig");

pub const Handshake = struct {
    protocol_version: types.VarInt,
    server_address: []u8,
    server_port: types.UShort,
    next_state: types.VarInt,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !Handshake {
        const protocol_version = (try types.readVarInt(reader)).value;
        const server_address = try types.readString(reader, allocator);
        const server_port = try types.readUShort(reader);
        const next_state = (try types.readVarInt(reader)).value;
        return .{ .protocol_version = protocol_version, .server_address = server_address, .server_port = server_port, .next_state = next_state };
    }
};

pub const LegacyServerListPing = struct {
    payload: types.UByte,

    pub fn read(reader: anytype) !LegacyServerListPing {
        const payload = try types.readUByte(reader);
        return .{ .payload = payload };
    }
};

pub const Request = struct {
    pub fn read(reader: anytype) !Request {
        _ = reader; // No fields to read
        return .{};
    }
};

pub const Ping = struct {
    payload: types.Long,

    pub fn read(reader: anytype) !Ping {
        const payload = try types.readLong(reader);
        return .{ .payload = payload };
    }
};

pub const LoginStart = struct {
    name: []u8,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !LoginStart {
        const name = try types.readString(reader, allocator);
        return .{ .name = name };
    }
};

pub const EncryptionResponse = struct {
    shared_secret_length: types.VarInt,
    shared_secret: []u8,
    verify_token_length: types.VarInt,
    verify_token: []u8,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !EncryptionResponse {
        const shared_secret_length = (try types.readVarInt(reader)).value;
        const shared_secret = try allocator.alloc(u8, @as(usize, @intCast(shared_secret_length)));
        try reader.readNoEof(shared_secret);

        const verify_token_length = (try types.readVarInt(reader)).value;
        const verify_token = try allocator.alloc(u8, @as(usize, @intCast(verify_token_length)));
        try reader.readNoEof(verify_token);

        return .{ .shared_secret_length = shared_secret_length, .shared_secret = shared_secret, .verify_token_length = verify_token_length, .verify_token = verify_token };
    }
};

pub const KeepAlive = struct {
    pub const id: i32 = 0x00;
    keep_alive_id: types.VarInt,

    pub fn read(reader: anytype) !KeepAlive {
        const keep_alive_id = (try types.readVarInt(reader)).value;
        return .{ .keep_alive_id = keep_alive_id };
    }
};

pub const ChatMessage = struct {
    pub const id: i32 = 0x01;
    message: []u8,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !ChatMessage {
        const message = try types.readString(reader, allocator);
        return .{ .message = message };
    }
};

pub const UseEntity = struct {
    target: types.VarInt,
    type: types.VarInt,
    target_x: ?types.Float,
    target_y: ?types.Float,
    target_z: ?types.Float,

    pub fn read(reader: anytype) !UseEntity {
        const target = (try types.readVarInt(reader)).value;
        const type_val = (try types.readVarInt(reader)).value;

        var target_x: ?types.Float = null;
        var target_y: ?types.Float = null;
        var target_z: ?types.Float = null;

        if (type_val == 2) { // interact at
            target_x = try types.readFloat(reader);
            target_y = try types.readFloat(reader);
            target_z = try types.readFloat(reader);
        }

        return .{ .target = target, .type = type_val, .target_x = target_x, .target_y = target_y, .target_z = target_z };
    }
};

pub const Player = struct {
    on_ground: types.Boolean,

    pub fn read(reader: anytype) !Player {
        const on_ground = try types.readBoolean(reader);
        return .{ .on_ground = on_ground };
    }
};

pub const PlayerPosition = struct {
    x: types.Double,
    feet_y: types.Double,
    z: types.Double,
    on_ground: types.Boolean,

    pub fn read(reader: anytype) !PlayerPosition {
        const x = try types.readDouble(reader);
        const feet_y = try types.readDouble(reader);
        const z = try types.readDouble(reader);
        const on_ground = try types.readBoolean(reader);
        return .{ .x = x, .feet_y = feet_y, .z = z, .on_ground = on_ground };
    }
};

pub const PlayerLook = struct {
    yaw: types.Float,
    pitch: types.Float,
    on_ground: types.Boolean,

    pub fn read(reader: anytype) !PlayerLook {
        const yaw = try types.readFloat(reader);
        const pitch = try types.readFloat(reader);
        const on_ground = try types.readBoolean(reader);
        return .{ .yaw = yaw, .pitch = pitch, .on_ground = on_ground };
    }
};

pub const PlayerPositionAndLook = struct {
    x: types.Double,
    feet_y: types.Double,
    z: types.Double,
    yaw: types.Float,
    pitch: types.Float,
    on_ground: types.Boolean,

    pub fn read(reader: anytype) !PlayerPositionAndLook {
        const x = try types.readDouble(reader);
        const feet_y = try types.readDouble(reader);
        const z = try types.readDouble(reader);
        const yaw = try types.readFloat(reader);
        const pitch = try types.readFloat(reader);
        const on_ground = try types.readBoolean(reader);
        return .{ .x = x, .feet_y = feet_y, .z = z, .yaw = yaw, .pitch = pitch, .on_ground = on_ground };
    }
};

pub const PlayerDigging = struct {
    status: types.Byte,
    location: types.Position,
    face: types.Byte,

    pub fn read(reader: anytype) !PlayerDigging {
        const status = try types.readByte(reader);
        const location = try types.Position.read(reader);
        const face = try types.readByte(reader);
        return .{ .status = status, .location = location, .face = face };
    }
};

pub const PlayerBlockPlacement = struct {
    location: types.Position,
    face: types.Byte,
    held_item_slot: types.Short,
    cursor_position_x: types.UByte,
    cursor_position_y: types.UByte,
    cursor_position_z: types.UByte,

    pub fn read(reader: anytype) !PlayerBlockPlacement {
        const location = try types.Position.read(reader);
        const face = try types.readByte(reader);
        const held_item_slot = try types.readShort(reader);
        const cursor_position_x = try types.readUByte(reader);
        const cursor_position_y = try types.readUByte(reader);
        const cursor_position_z = try types.readUByte(reader);
        return .{ .location = location, .face = face, .held_item_slot = held_item_slot, .cursor_position_x = cursor_position_x, .cursor_position_y = cursor_position_y, .cursor_position_z = cursor_position_z };
    }
};

pub const HeldItemChange = struct {
    slot: types.Short,

    pub fn read(reader: anytype) !HeldItemChange {
        const slot = try types.readShort(reader);
        return .{ .slot = slot };
    }
};

pub const Animation = struct {
    pub fn read(reader: anytype) !Animation {
        _ = reader; // No fields
        return .{};
    }
};

pub const EntityAction = struct {
    entity_id: types.VarInt,
    action_id: types.VarInt,
    action_parameter: types.VarInt,

    pub fn read(reader: anytype) !EntityAction {
        const entity_id = (try types.readVarInt(reader)).value;
        const action_id = (try types.readVarInt(reader)).value;
        const action_parameter = (try types.readVarInt(reader)).value;
        return .{ .entity_id = entity_id, .action_id = action_id, .action_parameter = action_parameter };
    }
};

pub const SteerVehicle = struct {
    sideways: types.Float,
    forward: types.Float,
    flags: types.UByte,

    pub fn read(reader: anytype) !SteerVehicle {
        const sideways = try types.readFloat(reader);
        const forward = try types.readFloat(reader);
        const flags = try types.readUByte(reader);
        return .{ .sideways = sideways, .forward = forward, .flags = flags };
    }
};

pub const CloseWindow = struct {
    window_id: types.UByte,

    pub fn read(reader: anytype) !CloseWindow {
        const window_id = try types.readUByte(reader);
        return .{ .window_id = window_id };
    }
};

pub const ClickWindow = struct {
    window_id: types.UByte,
    slot: types.Short,
    button: types.Byte,
    action_number: types.Short,
    mode: types.Byte,
    clicked_item: types.ItemSlot,

    pub fn read(reader: anytype) !ClickWindow {
        const window_id = try types.readUByte(reader);
        const slot = try types.readShort(reader);
        const button = try types.readByte(reader);
        const action_number = try types.readShort(reader);
        const mode = try types.readByte(reader);
        const clicked_item = try types.ItemSlot.read(reader);
        return .{ .window_id = window_id, .slot = slot, .button = button, .action_number = action_number, .mode = mode, .clicked_item = clicked_item };
    }
};

pub const ConfirmTransaction = struct {
    window_id: types.Byte,
    action_number: types.Short,
    accepted: types.Boolean,

    pub fn read(reader: anytype) !ConfirmTransaction {
        const window_id = try types.readByte(reader);
        const action_number = try types.readShort(reader);
        const accepted = try types.readBoolean(reader);
        return .{ .window_id = window_id, .action_number = action_number, .accepted = accepted };
    }
};

pub const CreativeInventoryAction = struct {
    slot: types.Short,
    clicked_item: types.ItemSlot,

    pub fn read(reader: anytype) !CreativeInventoryAction {
        const slot = try types.readShort(reader);
        const clicked_item = try types.ItemSlot.read(reader);
        return .{ .slot = slot, .clicked_item = clicked_item };
    }
};

pub const EnchantItem = struct {
    window_id: types.Byte,
    enchantment: types.Byte,

    pub fn read(reader: anytype) !EnchantItem {
        const window_id = try types.readByte(reader);
        const enchantment = try types.readByte(reader);
        return .{ .window_id = window_id, .enchantment = enchantment };
    }
};

pub const UpdateSign = struct {
    location: types.Position,
    line1: types.Chat,
    line2: types.Chat,
    line3: types.Chat,
    line4: types.Chat,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !UpdateSign {
        const location = try types.Position.read(reader);
        const line1 = try types.readChat(reader, allocator);
        const line2 = try types.readChat(reader, allocator);
        const line3 = try types.readChat(reader, allocator);
        const line4 = try types.readChat(reader, allocator);
        return .{ .location = location, .line1 = line1, .line2 = line2, .line3 = line3, .line4 = line4 };
    }
};

pub const PlayerAbilities = struct {
    flags: types.Byte,
    flying_speed: types.Float,
    walking_speed: types.Float,

    pub fn read(reader: anytype) !PlayerAbilities {
        const flags = try types.readByte(reader);
        const flying_speed = try types.readFloat(reader);
        const walking_speed = try types.readFloat(reader);
        return .{ .flags = flags, .flying_speed = flying_speed, .walking_speed = walking_speed };
    }
};

pub const TabComplete = struct {
    text: []u8,
    has_position: types.Boolean,
    looked_at_block: ?types.Position,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !TabComplete {
        const text = try types.readString(reader, allocator);
        const has_position = try types.readBoolean(reader);
        var looked_at_block: ?types.Position = null;
        if (has_position) {
            looked_at_block = try types.Position.read(reader);
        }
        return .{ .text = text, .has_position = has_position, .looked_at_block = looked_at_block };
    }
};

pub const ClientSettings = struct {
    locale: []u8,
    view_distance: types.Byte,
    chat_mode: types.Byte,
    chat_colors: types.Boolean,
    displayed_skin_parts: types.UByte,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !ClientSettings {
        const locale = try types.readString(reader, allocator);
        const view_distance = try types.readByte(reader);
        const chat_mode = try types.readByte(reader);
        const chat_colors = try types.readBoolean(reader);
        const displayed_skin_parts = try types.readUByte(reader);
        return .{ .locale = locale, .view_distance = view_distance, .chat_mode = chat_mode, .chat_colors = chat_colors, .displayed_skin_parts = displayed_skin_parts };
    }
};

pub const ClientStatus = struct {
    action_id: types.VarInt,

    pub fn read(reader: anytype) !ClientStatus {
        const action_id = (try types.readVarInt(reader)).value;
        return .{ .action_id = action_id };
    }
};

pub const PluginMessage = struct {
    channel: []u8,
    data: []u8,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !PluginMessage {
        const channel = try types.readString(reader, allocator);
        // The data length is not explicitly given, it's the rest of the packet
        // For now, we'll read until EOF or a reasonable limit.
        // In a real implementation, you'd need the packet length from the outer VarInt.
        var data_buffer = std.ArrayList(u8).init(allocator);
        while (reader.readByte()) |byte| {
            try data_buffer.append(byte);
        } else |err| {
            if (err != error.EndOfStream) return err;
        }
        return .{ .channel = channel, .data = data_buffer.toOwnedSlice() };
    }
};

pub const Spectate = struct {
    target_player_uuid: types.UUID,

    pub fn read(reader: anytype) !Spectate {
        const target_player_uuid = try types.readUUID(reader);
        return .{ .target_player_uuid = target_player_uuid };
    }
};

pub const ResourcePackStatus = struct {
    hash: []u8,
    result: types.VarInt,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !ResourcePackStatus {
        const hash = try types.readString(reader, allocator);
        const result = (try types.readVarInt(reader)).value;
        return .{ .hash = hash, .result = result };
    }
};
