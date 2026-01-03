const std = @import("std");
pub const types = @import("types.zig");
pub const serverbound = @import("serverbound.zig");
pub const clientbound = @import("clientbound.zig");

pub const State = enum {
    Handshaking,
    Status,
    Login,
    Play,
};

// Handshaking Packets
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

// Status Packets
pub const Status = struct {
    pub const Request = struct {
        pub fn read(reader: anytype) !Request {
            _ = reader; // No fields to read
            return .{};
        }
    };

    pub const Response = struct {
        json_response: []const u8,

        pub fn write(writer: anytype, response: Response, allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            const temp_writer = buffer.writer();

            try types.writeVarInt(temp_writer, 0x00); // Packet ID
            try types.writeString(temp_writer, response.json_response);

            try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
            try writer.writeAll(buffer.items);
        }
    };

    pub const Ping = struct {
        payload: types.Long,

        pub fn read(reader: anytype) !Ping {
            const payload = try types.readLong(reader);
            return .{ .payload = payload };
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
};

// Login Packets
pub const Login = struct {
    pub const LoginStart = serverbound.LoginStart;
    pub const EncryptionResponse = serverbound.EncryptionResponse;

    pub const Disconnect = clientbound.LoginDisconnect;
    pub const EncryptionRequest = clientbound.EncryptionRequest;
    pub const LoginSuccess = clientbound.LoginSuccess;
    pub const SetCompression = clientbound.SetCompression;
};

// Play Packets
pub const Play = struct {
    pub const KeepAlive = clientbound.KeepAlive;
    pub const ChatMessage = clientbound.ChatMessage;
    pub const TimeUpdate = clientbound.TimeUpdate;
    pub const JoinGame = clientbound.JoinGame;
    pub const PlayerPositionAndLook = clientbound.PlayerPositionAndLook;
    pub const ChunkData = clientbound.ChunkData;
    pub const SpawnPlayer = clientbound.SpawnPlayer;
    pub const DestroyEntities = clientbound.DestroyEntities;
    pub const EntityTeleport = clientbound.EntityTeleport;
    pub const PlayerListItem = clientbound.PlayerListItem;
    pub const EntityEquipment = clientbound.EntityEquipment;
    pub const SpawnPosition = clientbound.SpawnPosition;
    pub const UpdateHealth = clientbound.UpdateHealth;
    pub const Respawn = clientbound.Respawn;
    pub const HeldItemChange = clientbound.HeldItemChange;
    pub const Animation = clientbound.Animation;
    pub const SpawnObject = clientbound.SpawnObject;
    pub const SpawnMob = clientbound.SpawnMob;
};
