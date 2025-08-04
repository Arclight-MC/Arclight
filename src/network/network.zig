const std = @import("std");

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
    reader: std.io.BufferedReader(4096, std.net.Stream.Reader),
    writer: std.io.BufferedWriter(4096, std.net.Stream.Writer),

    pub fn init(allocator: std.mem.Allocator, conn: std.net.Server.Connection) TcpClient {
        return .{
            .allocator = allocator,
            .conn = conn,
            .reader = std.io.bufferedReader(conn.stream.reader()),
            .writer = std.io.bufferedWriter(conn.stream.writer()),
        };
    }

    pub fn deinit(self: *TcpClient) void {
        self.conn.stream.close();
    }

    pub fn getReader(self: *TcpClient) std.io.BufferedReader(4096, std.net.Stream.Reader).Reader {
        return self.reader.reader();
    }

    pub fn getWriter(self: *TcpClient) std.io.BufferedWriter(4096, std.net.Stream.Writer).Writer {
        return self.writer.writer();
    }

    pub fn address(self: *TcpClient) std.net.Address {
        return self.conn.address;
    }
};