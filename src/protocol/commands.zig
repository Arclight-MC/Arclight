const std = @import("std");
const clientbound = @import("./clientbound.zig");

var game_time: i64 = 0;
var player_count: usize = 1;

pub const CommandManager = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CommandManager {
        return .{ .allocator = allocator };
    }

    pub fn execute(self: *CommandManager, input: []u8, sender_name: []const u8, writer: anytype, allocator: std.mem.Allocator) !void {
        _ = self;

        const trimmed = std.mem.trim(u8, input, " ");
        if (trimmed.len == 0) return;

        var space_index: usize = 0;
        for (trimmed, 0..) |c, i| {
            if (c == ' ') {
                space_index = i;
                break;
            }
        }

        var cmd_name: []const u8 = undefined;
        var args_start: usize = undefined;

        if (space_index > 0) {
            cmd_name = trimmed[0..space_index];
            args_start = space_index + 1;
        } else {
            cmd_name = trimmed;
            args_start = trimmed.len;
        }

        const args = if (args_start < trimmed.len) trimmed[args_start..] else "";

        if (std.mem.eql(u8, cmd_name, "help")) {
            try helpCommand(allocator, writer);
        } else if (std.mem.eql(u8, cmd_name, "say")) {
            try sayCommand(args, sender_name, allocator, writer);
        } else if (std.mem.eql(u8, cmd_name, "time")) {
            try timeCommand(args, allocator, writer);
        } else if (std.mem.eql(u8, cmd_name, "list") or std.mem.eql(u8, cmd_name, "players") or std.mem.eql(u8, cmd_name, "online")) {
            try listCommand(allocator, writer);
        } else if (std.mem.eql(u8, cmd_name, "me")) {
            try meCommand(args, sender_name, allocator, writer);
        } else {
            try clientbound.ChatMessage.write(writer, .{
                .json_data = try std.fmt.allocPrint(allocator, "{{\"text\":\"Unknown command: {s}. Type /help for help.\"}}", .{cmd_name}),
                .position = 0,
            }, allocator);
        }
    }
};

fn sendChat(allocator: std.mem.Allocator, writer: anytype, text: []const u8) !void {
    try clientbound.ChatMessage.write(writer, .{
        .json_data = try std.fmt.allocPrint(allocator, "{{\"text\":\"{s}\"}}", .{text}),
        .position = 0,
    }, allocator);
}

fn helpCommand(allocator: std.mem.Allocator, writer: anytype) !void {
    try sendChat(allocator, writer, "Available commands: /help, /say, /time, /list, /me");
}

fn sayCommand(args: []const u8, sender_name: []const u8, allocator: std.mem.Allocator, writer: anytype) !void {
    if (args.len == 0) {
        try sendChat(allocator, writer, "Usage: /say <message>");
        return;
    }

    try clientbound.ChatMessage.write(writer, .{
        .json_data = try std.fmt.allocPrint(allocator, "{{\"text\":\"[{s}] {s}\"}}", .{ sender_name, args }),
        .position = 0,
    }, allocator);
}

fn timeCommand(args: []const u8, allocator: std.mem.Allocator, writer: anytype) !void {
    var space_idx: usize = 0;
    for (args, 0..) |c, i| {
        if (c == ' ') {
            space_idx = i;
            break;
        }
    }

    if (space_idx == 0 or args.len == 0) {
        try sendChat(allocator, writer, "Usage: /time <set|add> <value>");
        return;
    }

    const action = args[0..space_idx];
    const value_str = args[space_idx + 1 ..];

    if (value_str.len == 0) {
        try sendChat(allocator, writer, "Usage: /time <set|add> <value>");
        return;
    }

    const value = std.fmt.parseInt(i64, value_str, 10) catch {
        try sendChat(allocator, writer, "Invalid number");
        return;
    };

    if (std.mem.eql(u8, action, "set")) {
        game_time = value;
        try sendChat(allocator, writer, try std.fmt.allocPrint(allocator, "Time set to {}", .{value}));
    } else if (std.mem.eql(u8, action, "add")) {
        game_time += value;
        try sendChat(allocator, writer, try std.fmt.allocPrint(allocator, "Time added {}", .{value}));
    } else {
        try sendChat(allocator, writer, "Usage: /time <set|add> <value>");
    }
}

fn listCommand(allocator: std.mem.Allocator, writer: anytype) !void {
    try sendChat(allocator, writer, try std.fmt.allocPrint(allocator, "Players online: {}", .{player_count}));
}

fn meCommand(args: []const u8, sender_name: []const u8, allocator: std.mem.Allocator, writer: anytype) !void {
    if (args.len == 0) {
        try sendChat(allocator, writer, "Usage: /me <action>");
        return;
    }

    try clientbound.ChatMessage.write(writer, .{
        .json_data = try std.fmt.allocPrint(allocator, "{{\"text\":\"* {s} {s}\"}}", .{ sender_name, args }),
        .position = 0,
    }, allocator);
}
