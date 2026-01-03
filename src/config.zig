const std = @import("std");
const toml = @import("toml");

pub const default_online_mode = false;

pub const default_config: Config = .{};

pub const Config = struct {
    server: ServerConfig = .{},
    thread_pool: ThreadPoolConfig = .{},
    online_mode: bool = true,

    pub const ServerConfig = struct {
        port: u16 = 25565,
        address: []const u8 = "0.0.0.0",
        max_connections: u16 = 100,
    };

    pub const ThreadPoolConfig = struct {
        max_threads: u16 = 4,
    };

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Config {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.log.warn("Could not open config file '{s}': {s}. Using default config.", .{ path, @errorName(err) });
            return Config{};
        };
        defer file.close();

        const size = (try file.stat()).size;
        const contents = try file.readToEndAlloc(allocator, size);
        defer allocator.free(contents);

        var parser = toml.Parser(Config).init(allocator);
        defer parser.deinit();

        const parsed = parser.parseString(contents) catch |err| {
            std.log.warn("Failed to parse config file: {s}", .{@errorName(err)});
            return Config{};
        };
        return parsed.value;
    }
};
