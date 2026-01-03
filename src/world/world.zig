const std = @import("std");
const crypto = std.crypto;

pub const CHUNK_SIZE = 16;
pub const CHUNK_HEIGHT = 128;

pub const BlockId = u8;
pub const BlockMetadata = u4;

pub const Block = packed struct {
    id: BlockId,
    metadata: BlockMetadata,
};

pub const Chunk = struct {
    x: i32,
    z: i32,
    blocks: [CHUNK_SIZE][CHUNK_HEIGHT][CHUNK_SIZE]Block,
    light_dirty: bool = false,

    pub fn init(x: i32, z: i32, seed: u64) Chunk {
        var chunk: Chunk = undefined;
        @memset(@as([*]u8, @ptrCast(&chunk.blocks))[0..@sizeOf(@TypeOf(chunk.blocks))], 0);

        chunk.x = x;
        chunk.z = z;

        generateTerrain(&chunk, seed);

        return chunk;
    }

    fn generateTerrain(chunk: *Chunk, seed: u64) void {
        for (0..CHUNK_SIZE) |x| {
            for (0..CHUNK_SIZE) |z| {
                const world_x = @as(i32, @intCast(x)) + chunk.x * CHUNK_SIZE;
                const world_z = @as(i32, @intCast(z)) + chunk.z * CHUNK_SIZE;

                const height = getHeight(world_x, world_z, seed);

                for (0..CHUNK_HEIGHT) |y| {
                    const block_y = @as(i32, @intCast(y));
                    if (block_y < height - 3) {
                        chunk.blocks[x][y][z] = .{ .id = 1, .metadata = 0 }; // Stone
                    } else if (block_y < height) {
                        chunk.blocks[x][y][z] = .{ .id = 3, .metadata = 0 }; // Dirt
                    } else if (block_y == height) {
                        chunk.blocks[x][y][z] = .{ .id = 2, .metadata = 0 }; // Grass
                    } else {
                        chunk.blocks[x][y][z] = .{ .id = 0, .metadata = 0 }; // Air
                    }
                }
            }
        }
    }

    fn getHeight(x: i32, z: i32, seed: u64) i32 {
        const h = simpleHash(x, z, seed);
        const normalized = @as(f32, @floatFromInt(h % 10000)) / 10000.0;
        return @as(i32, @intFromFloat(normalized * 20.0)) + 10;
    }

    fn simpleHash(x: i32, z: i32, seed: u64) u64 {
        var h = seed;
        h = h * 31 + @as(u64, @intCast(x));
        h = h * 31 + @as(u64, @intCast(z));
        h = h * 31 + (h >> 32);
        return h & 0x7FFFFFFFFFFFFFFF;
    }

    pub fn getBlock(chunk: *const Chunk, x: usize, y: usize, z: usize) Block {
        if (x >= CHUNK_SIZE or y >= CHUNK_HEIGHT or z >= CHUNK_SIZE) {
            return .{ .id = 0, .metadata = 0 };
        }
        return chunk.blocks[x][y][z];
    }
};

pub const World = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    chunks: std.AutoHashMap(u64, Chunk),

    pub fn init(allocator: std.mem.Allocator, seed_val: u64) !World {
        return .{
            .allocator = allocator,
            .seed = seed_val,
            .chunks = std.AutoHashMap(u64, Chunk).init(allocator),
        };
    }

    pub fn deinit(self: *World) void {
        self.chunks.deinit();
    }

    pub fn tick(self: *World) void {
        _ = self;
    }

    pub fn getChunk(self: *World, x: i32, z: i32) !*Chunk {
        const key = getChunkKey(x, z);

        if (self.chunks.get(key)) |chunk| {
            return @ptrCast(@constCast(&chunk));
        }

        const new_chunk = Chunk.init(x, z, self.seed);
        try self.chunks.put(key, new_chunk);
        return @ptrCast(@constCast(&self.chunks.get(key).?));
    }

    pub fn getBlockAt(self: *World, x: i32, y: i32, z: i32) Block {
        const chunk_x = @divFloor(x, CHUNK_SIZE);
        const chunk_z = @divFloor(z, CHUNK_SIZE);
        const local_x = @mod(x, CHUNK_SIZE);
        const local_z = @mod(z, CHUNK_SIZE);

        if (self.chunks.get(getChunkKey(chunk_x, chunk_z))) |chunk| {
            return chunk.getBlock(@intCast(local_x), @intCast(y), @intCast(local_z));
        }

        return .{ .id = 0, .metadata = 0 };
    }

    fn getChunkKey(x: i32, z: i32) u64 {
        return (@as(u64, @intCast(x)) & 0xFFFFFFFF) | (@as(u64, @intCast(z)) & 0xFFFFFFFF) << 32;
    }
};
