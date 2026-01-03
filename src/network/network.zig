const std = @import("std");
const crypto = @import("../protocol/crypto.zig");
const types = @import("../protocol/types.zig");

pub const TcpServer = struct {
    allocator: std.mem.Allocator,
    server: std.net.Server,

    pub fn init(allocator: std.mem.Allocator, port: u16) !TcpServer {
        const address = try std.net.Address.parseIp4("0.0.0.0", port);
        const server = try address.listen(.{ .reuse_address = true });
        return .{ .allocator = allocator, .server = server };
    }

    pub fn deinit(self: *TcpServer) void {
        self.server.deinit();
    }

    pub fn accept(self: *TcpServer) !TcpClient {
        const conn = try self.server.accept();
        return TcpClient.init(self.allocator, conn);
    }
};

pub const TcpClient = struct {
    allocator: std.mem.Allocator,
    conn: std.net.Server.Connection,
    read_buffer: [4096]u8,
    write_buffer: [4096]u8,
    cipher: ?crypto.AesCfb8Stream = null,
    compression_threshold: i32 = -1,
    writer_wrapper: WriterWrapper,

    pub fn init(allocator: std.mem.Allocator, conn: std.net.Server.Connection) !TcpClient {
        var client: TcpClient = undefined;
        client.allocator = allocator;
        client.conn = conn;
        client.read_buffer = std.mem.zeroes([4096]u8);
        client.write_buffer = std.mem.zeroes([4096]u8);
        client.writer_wrapper = WriterWrapper{ .stream = conn.stream, .buffer = client.write_buffer[0..] };
        return client;
    }

    pub fn deinit(self: *TcpClient) void {
        self.conn.stream.close();
    }

    pub fn getReader(self: *TcpClient) ReaderWrapper {
        return ReaderWrapper{ .stream = self.conn.stream, .buffer = self.read_buffer[0..] };
    }

    pub fn getWriter(self: *TcpClient) WriterWrapper {
        return WriterWrapper{ .stream = self.conn.stream, .buffer = self.write_buffer[0..] };
    }

    pub fn address(self: *TcpClient) std.net.Address {
        return self.conn.address;
    }

    pub fn enableEncryption(self: *TcpClient, shared_secret: []const u8) !void {
        self.cipher = try crypto.AesCfb8Stream.init(self.conn.stream, shared_secret);
    }

    pub fn enableCompression(self: *TcpClient, threshold: i32) !void {
        self.compression_threshold = threshold;
    }

    pub fn poll(self: *TcpClient, timeout_ms: i32) !bool {
        _ = self;
        _ = timeout_ms;
        return true;
    }
};

pub const ReaderWrapper = struct {
    stream: std.net.Stream,
    buffer: []u8,

    pub fn readByte(self: ReaderWrapper) !u8 {
        var buf: [1]u8 = undefined;
        const n = self.stream.read(buf[0..]) catch |err| return err;
        if (n == 0) return error.EndOfStream;
        return buf[0];
    }

    pub fn readInt(self: ReaderWrapper, comptime T: type, endian: std.mem.Endian) !T {
        const size = @typeInfo(T).Int.bits / 8;
        var buf: [16]u8 = undefined;
        if (size > 16) return error.Overflow;
        const n = self.stream.read(buf[0..size]) catch |err| return err;
        if (n < size) return error.EndOfStream;
        return std.mem.readInt(T, buf[0..size], endian);
    }

    pub fn readNoEof(self: ReaderWrapper, buffer: []u8) !void {
        var remaining = buffer;
        while (remaining.len > 0) {
            const n = self.stream.read(remaining) catch |err| return err;
            if (n == 0) return error.EndOfStream;
            remaining = remaining[n..];
        }
    }
};

pub const WriterWrapper = struct {
    stream: std.net.Stream,
    buffer: []u8,

    pub fn writeByte(self: WriterWrapper, byte: u8) !void {
        const buf: [1]u8 = .{byte};
        _ = try self.stream.write(buf[0..]);
    }

    pub fn writeInt(self: WriterWrapper, comptime T: type, value: T, endian: std.mem.Endian) !void {
        const size = @typeInfo(T).Int.bits / 8;
        var buf: [16]u8 = undefined;
        if (size > 16) return error.Overflow;
        std.mem.writeInt(T, buf[0..size], value, endian);
        _ = try self.stream.write(buf[0..size]);
    }

    pub fn writeAll(self: WriterWrapper, buffer: []const u8) !void {
        _ = try self.stream.write(buffer);
    }

    pub fn flush(self: WriterWrapper) !void {
        // No-op: writes are immediate to the stream
        _ = self;
    }
};
