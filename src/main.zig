const std = @import("std");
const event_loop = @import("event_loop.zig");
const mode = @import("builtin").mode;

var debugAllocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const allocator: std.mem.Allocator = switch (mode) {
        .Debug, .ReleaseSafe => debugAllocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.c_allocator,
    };

    var el = try event_loop.EventLoop.init(allocator, "config.toml");
    defer el.deinit();

    try el.run();
}
