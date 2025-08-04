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

pub const Packet = union(enum) {
    // Handshaking
    handshake: Handshake,
    legacy_server_list_ping: LegacyServerListPing,

    // Status
    status_request: Status.Request,
    status_response: Status.Response,
    ping: Status.Ping,
    pong: Status.Pong,

    // Login
    login_start: Login.LoginStart,
    login_success: Login.LoginSuccess,
    encryption_request: Login.EncryptionRequest,
    encryption_response: Login.EncryptionResponse,
    login_disconnect: Login.Disconnect,
    login_set_compression: Login.SetCompression,

    // Play (placeholder for now)
    play_keep_alive: Play.KeepAlive,
    play_chat_message: Play.ChatMessage,
    // ... many more play packets

    pub fn read(reader: anytype, state: State, allocator: std.mem.Allocator) !Packet {
        const packet_id_info = try types.readVarInt(reader);
        const packet_id = packet_id_info.value;

        return switch (state) {
            .Handshaking => switch (packet_id) {
                0x00 => .{ .handshake = try Handshake.read(reader, allocator) },
                0xFE => .{ .legacy_server_list_ping = try LegacyServerListPing.read(reader) },
                else => error.UnknownPacket,
            },
            .Status => switch (packet_id) {
                0x00 => .{ .status_request = try Status.Request.read(reader) },
                0x01 => .{ .ping = try Status.Ping.read(reader) },
                else => error.UnknownPacket,
            },
            .Login => switch (packet_id) {
                0x00 => .{ .login_start = try Login.LoginStart.read(reader, allocator) },
                0x01 => .{ .encryption_response = try Login.EncryptionResponse.read(reader, allocator) },
                else => error.UnknownPacket,
            },
            .Play => switch (packet_id) {
                // TODO: Implement Play state packets
                else => error.UnknownPacket,
            },
        };
    }

    pub fn write(writer: anytype, packet: Packet, allocator: std.mem.Allocator) !void {
        const buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        const temp_writer = buffer.writer();

        switch (packet) {
            .handshake => {},
            .legacy_server_list_ping => {},
            .status_request => {},
            .status_response => {
                try types.writeVarInt(temp_writer, 0x00);
                try types.writeString(temp_writer, packet.status_response.json_response);
            },
            .ping => {},
            .pong => {
                try types.writeVarInt(temp_writer, 0x01);
                try types.writeLong(temp_writer, packet.pong.payload);
            },
            .login_start => {},
            .login_success => {
                try types.writeVarInt(temp_writer, 0x02);
                try types.writeString(temp_writer, packet.login_success.uuid);
                try types.writeString(temp_writer, packet.login_success.username);
            },
            .encryption_request => {},
            .encryption_response => {},
            .login_disconnect => {},
            .login_set_compression => {},
            .play_keep_alive => {},
            .play_chat_message => {},
        }

        try types.writeVarInt(writer, @as(i32, @intCast(buffer.items.len)));
        try writer.writeAll(buffer.items);
    }
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
    pub const LoginStart = struct {
        name: []u8,

        pub fn read(reader: anytype, allocator: std.mem.Allocator) !LoginStart {
            const name = try types.readString(reader, allocator);
            return .{ .name = name };
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

    pub const EncryptionRequest = struct {
        // TODO: Implement fields
        pub fn read(reader: anytype) !EncryptionRequest {
            _ = reader;
            return .{};
        }
        pub fn write(writer: anytype, req: EncryptionRequest) !void {
            _ = writer;
            _ = req;
        }
    };

    pub const EncryptionResponse = struct {
        // TODO: Implement fields
        pub fn read(reader: anytype, allocator: std.mem.Allocator) !EncryptionResponse {
            _ = reader;
            _ = allocator;
            return .{};
        }
        pub fn write(writer: anytype, res: EncryptionResponse) !void {
            _ = writer;
            _ = res;
        }
    };

    pub const Disconnect = struct {
        // TODO: Implement fields
        pub fn read(reader: anytype) !Disconnect {
            _ = reader;
            return .{};
        }
        pub fn write(writer: anytype, disc: Disconnect) !void {
            _ = writer;
            _ = disc;
        }
    };

    pub const SetCompression = struct {
        // TODO: Implement fields
        pub fn read(reader: anytype) !SetCompression {
            _ = reader;
            return .{};
        }
        pub fn write(writer: anytype, sc: SetCompression) !void {
            _ = writer;
            _ = sc;
        }
    };
};

// Play Packets (placeholders)
pub const Play = struct {
    pub const KeepAlive = struct {
        // TODO: Implement fields
        pub fn read(reader: anytype) !KeepAlive {
            _ = reader;
            return .{};
        }
        pub fn write(writer: anytype, ka: KeepAlive) !void {
            _ = writer;
            _ = ka;
        }
    };

    pub const ChatMessage = struct {
        // TODO: Implement fields
        pub fn read(reader: anytype) !ChatMessage {
            _ = reader;
            return .{};
        }
        pub fn write(writer: anytype, cm: ChatMessage) !void {
            _ = writer;
            _ = cm;
        }
    };
};
