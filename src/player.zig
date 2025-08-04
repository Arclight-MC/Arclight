const std = @import("std");

pub const Player = struct {
    x: f64 = 0.0,
    y: f64 = 0.0,
    z: f64 = 0.0,
    yaw: f32 = 0.0,
    pitch: f32 = 0.0,
    on_ground: bool = false,
    entity_id: i32,
    name: []const u8,

    pub fn init(entity_id: i32, name: []const u8) Player {
        return .{ .entity_id = entity_id, .name = name };
    }
};
