const jni = @cImport({
    @cInclude("jni.h");
});
const std = @import("std");

pub const Interface = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Interface {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Interface) void {
        _ = self;
    }

    // TODO: Add Bukkit compatibility functions here later
};
