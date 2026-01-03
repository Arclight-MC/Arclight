const std = @import("std");
const network = @import("network/network.zig");
const config = @import("config.zig");
const handler = @import("protocol/handler.zig");
const ThreadPool = std.Thread.Pool;

pub const EventLoop = struct {
    allocator: std.mem.Allocator,
    server: network.TcpServer,
    thread_pool: ThreadPool,
    config: config.Config,

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8) !EventLoop {
        const cfg = try config.Config.load(allocator, config_path);
        const server = try network.TcpServer.init(allocator, cfg.server.port);

        var thread_pool: ThreadPool = undefined;
        try thread_pool.init(.{
            .allocator = allocator,
            .n_jobs = cfg.thread_pool.max_threads,
        });

        return .{
            .allocator = allocator,
            .server = server,
            .thread_pool = thread_pool,
            .config = cfg,
        };
    }

    pub fn deinit(self: *EventLoop) void {
        self.thread_pool.deinit();
        self.server.deinit();
    }

    pub fn run(self: *EventLoop) !void {
        std.debug.print("Server listening on {s}:{d}\n", .{ self.config.server.address, self.config.server.port });
        while (true) {
            var client = try self.server.accept();
            std.debug.print("Client connected: {any}\n", .{client.address()});
            try self.thread_pool.spawn(handleClientWrapper, .{
                client,
                self.allocator,
            });
        }
    }

    fn handleClientWrapper(client: network.TcpClient, parent_allocator: std.mem.Allocator) void {
        handler.handleClient(client, parent_allocator) catch |err| {
            std.log.err("Error handling client: {s}", .{@errorName(err)});
        };
    }
};
