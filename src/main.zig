// src/main.zig (updated)
const std = @import("std");
const network = @import("network/network.zig");

const protocol = @import("protocol/protocol.zig");
const serverbound = protocol.serverbound;

const player = @import("player.zig");
const Bukkit = @import("plugin/bukkit.zig");
const world = @import("world/world.zig");
const mode = @import("builtin").mode;

const ThreadPool = std.Thread.Pool;

var debugAllocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const allocator: std.mem.Allocator = switch (mode) {
        .Debug, .ReleaseSafe => debugAllocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.c_allocator,
    };

    const port = 25565;
    var server = try network.TcpServer.init(allocator, port);
    defer server.deinit();

    std.debug.print("Minecraft 1.8.9 server listening on port {d}\n", .{port});

    var bukkit_interface = Bukkit.Interface.init(allocator);
    defer bukkit_interface.deinit();

    var thread_pool: ThreadPool = undefined;
    try thread_pool.init(.{ .allocator = allocator });
    defer thread_pool.deinit();

    while (true) {
        var client = try server.accept();
        std.debug.print("Client connected: {any}\n", .{client.address()});
        try thread_pool.spawn(handleClientWrapper, .{ client, allocator });
    }
}

fn handleClientWrapper(client: network.TcpClient, parent_allocator: std.mem.Allocator) void {
    handleClient(client, parent_allocator) catch |err| {
        std.debug.print("Error handling client: {s}\n", .{@errorName(err)});
    };
}

fn handleClient(client: network.TcpClient, parent_allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(parent_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var g_client = client;
    defer g_client.deinit();

    const reader = g_client.getReader();
    const writer = g_client.getWriter();

    var current_state: protocol.State = .Handshaking;
    var game_world: ?world.World = null;
    var current_player: ?player.Player = null;

    while (true) {
        const packet_len_info = protocol.types.readVarInt(reader) catch |err| {
            if (err == error.EndOfStream) {
                std.debug.print("Client disconnected.\n", .{});
                return;
            }
            return err;
        };
        const packet_len = packet_len_info.value;

        const packet_buffer = try allocator.alloc(u8, @as(usize, @intCast(packet_len)));
        defer allocator.free(packet_buffer);
        try reader.readNoEof(packet_buffer);

        var buffer_stream = std.io.fixedBufferStream(packet_buffer);
        const buffer_reader = buffer_stream.reader();

        const packet_id_info = try protocol.types.readVarInt(buffer_reader);
        const packet_id = packet_id_info.value;

        switch (current_state) {
            .Handshaking => {
                switch (packet_id) {
                    0x00 => { // Handshake
                        const handshake_packet = try serverbound.Handshake.read(buffer_reader, allocator);
                        std.debug.print("Handshake: protocol_version={d}, server_address={s}, server_port={d}, next_state={d}\n", .{
                            handshake_packet.protocol_version,
                            handshake_packet.server_address,
                            handshake_packet.server_port,
                            handshake_packet.next_state,
                        });

                        switch (handshake_packet.next_state) {
                            1 => current_state = .Status,
                            2 => current_state = .Login,
                            else => {
                                std.debug.print("Unknown next state: {d}\n", .{handshake_packet.next_state});
                                return error.InvalidNextState;
                            },
                        }
                    },
                    0xFE => { // Legacy Server List Ping
                        std.debug.print("Legacy Server List Ping received, not implemented yet.\n", .{});
                        return error.NotImplemented;
                    },
                    else => {
                        std.debug.print("Unknown packet ID 0x{x} in Handshaking state.\n", .{packet_id});
                        return error.UnknownPacket;
                    },
                }
            },
            .Status => {
                switch (packet_id) {
                    0x00 => { // Request
                        std.debug.print("Status Request received.\n", .{});
                        const response_json =
                            \\{
                            \\  "version": {
                            \\    "name": "1.8.9",
                            \\    "protocol": 47
                            \\  },
                            \\  "players": {
                            \\    "max": 100,
                            \\    "online": 0,
                            \\    "sample": []
                            \\  },
                            \\  "description": {
                            \\    "text": "Arclight Zig Server"
                            \\  }
                            \\}
                        ;
                        const response_packet = protocol.clientbound.StatusResponse{ .json_response = response_json };
                        try protocol.clientbound.StatusResponse.write(writer, response_packet, allocator);
                        std.debug.print("Sent Status Response.\n", .{});
                    },
                    0x01 => { // Ping
                        const ping_packet = try serverbound.Ping.read(buffer_reader);
                        std.debug.print("Ping received with payload: {d}\n", .{ping_packet.payload});
                        const pong_packet = protocol.clientbound.Pong{ .payload = ping_packet.payload };
                        try protocol.clientbound.Pong.write(writer, pong_packet);
                        std.debug.print("Sent Pong response.\n", .{});
                        return; // Client will disconnect after this
                    },
                    else => {
                        std.debug.print("Unknown packet ID 0x{x} in Status state.\n", .{packet_id});
                        return error.UnknownPacket;
                    },
                }
            },
            .Login => {
                switch (packet_id) {
                    0x00 => { // Login Start
                        const login_start_packet = try serverbound.LoginStart.read(buffer_reader, allocator);
                        std.debug.print("Login Start: name={s}\n", .{login_start_packet.name});

                        const login_success_packet = protocol.clientbound.LoginSuccess{
                            .uuid = "4566e69f-c907-48ee-8d71-d7ba5aa200d0", // Dummy UUID
                            .username = login_start_packet.name,
                        };
                        try protocol.clientbound.LoginSuccess.write(writer, login_success_packet, allocator);
                        std.debug.print("Sent Login Success.\n", .{});
                        current_state = .Play;

                        game_world = try world.World.init(allocator);
                        current_player = player.Player.init(1, login_start_packet.name);

                        const join_game_packet = protocol.clientbound.JoinGame{
                            .entity_id = 1,
                            .gamemode = 1, // Creative
                            .dimension = 0, // Overworld
                            .difficulty = 0, // Peaceful
                            .max_players = 100,
                            .level_type = "default",
                            .reduced_debug_info = false,
                        };
                        try protocol.clientbound.JoinGame.write(writer, join_game_packet, allocator);
                        std.debug.print("Sent Join Game.\n", .{});

                        // Send a few chunks
                        var i: i32 = -2;
                        while (i <= 2) : (i += 1) {
                            var j: i32 = -2;
                            while (j <= 2) : (j += 1) {
                                const chunk_packet = try protocol.clientbound.ChunkData.init(allocator, i, j);
                                try chunk_packet.write(writer, allocator);
                            }
                        }

                        const pos_look_packet = protocol.clientbound.PlayerPositionAndLook{
                            .x = 0.0,
                            .y = 64.0,
                            .z = 0.0,
                            .yaw = 0.0,
                            .pitch = 0.0,
                            .flags = 0,
                        };
                        try protocol.clientbound.PlayerPositionAndLook.write(writer, pos_look_packet, allocator);
                        std.debug.print("Sent Player Position and Look.\n", .{});
                    },
                    else => {
                        std.debug.print("Unknown packet ID 0x{x} in Login state.\n", .{packet_id});
                        return error.UnknownPacket;
                    },
                }
            },
            .Play => {
                // Game loop
                var last_keep_alive = std.time.milliTimestamp();
                while (true) {
                    const now = std.time.milliTimestamp();
                    if (now - last_keep_alive > 15000) { // 15 seconds
                        const keep_alive_packet = protocol.clientbound.KeepAlive{ .keep_alive_id = @as(i32, @intCast(now)) };
                        try protocol.clientbound.KeepAlive.write(writer, keep_alive_packet, allocator);
                        last_keep_alive = now;
                    }

                    // Handle incoming packets with a timeout
                    // This part is tricky in a simple loop, but for now we just process one packet per loop
                    // A better implementation would use non-blocking I/O and an event loop.
                    break; // break out of game loop to read next packet
                }

                switch (packet_id) {
                    serverbound.KeepAlive.id => { // Keep Alive (serverbound)
                        const keep_alive = try protocol.serverbound.KeepAlive.read(buffer_reader);
                        std.debug.print("KeepAlive received: {d}\n", .{keep_alive.keep_alive_id});
                    },
                    serverbound.ChatMessage.id => { // Chat Message
                        const chat_packet = try protocol.serverbound.ChatMessage.read(buffer_reader, allocator);
                        std.debug.print("Chat from {s}: {s}\n", .{ current_player.?.name, chat_packet.message });
                    },
                    0x04, 0x05, 0x06 => { // Player Position/Look packets
                        // We can just ignore these for now
                    },
                    else => {
                        std.debug.print("Unhandled Play packet ID: 0x{x}\n", .{packet_id});
                    },
                }
            },
        }
    }
}
