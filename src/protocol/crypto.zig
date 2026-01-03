const std = @import("std");
const crypto = std.crypto;
const aes = std.crypto.core.aes;

pub const AES_BLOCK_SIZE = 16;
const Aes128 = aes.Aes128;

fn twosComplement(bytes: *[20]u8) void {
    var carry: bool = true;
    for (bytes, 0..) |*b, i| {
        _ = b;
        const j = bytes.len - 1 - i;
        bytes[j] = ~bytes[j];
        if (carry) {
            carry = bytes[j] == 0xff;
            bytes[j] +%= 1;
        }
    }
}

pub fn getSha1Digest(allocator: std.mem.Allocator, server_id: []const u8, shared_secret: []const u8, public_key: []const u8) ![]u8 {
    var sha1 = crypto.hash.Sha1.init(.{});
    sha1.update(server_id);
    sha1.update(shared_secret);
    sha1.update(public_key);

    var digest: [20]u8 = undefined;
    sha1.final(&digest);

    var result = try allocator.alloc(u8, 45);
    var result_len: usize = 0;

    if (digest[0] & 0x80 != 0) {
        twosComplement(&digest);
        result[0] = '-';
        result_len += 1;
    }

    var hex_buf: [40]u8 = std.fmt.bytesToHex(digest[0..], .lower);

    var i: usize = 0;
    while (hex_buf[i] == '0' and i < 39) {
        i += 1;
    }

    @memcpy(result[result_len..], hex_buf[i..]);
    result_len += 40 - i;

    return result[0..result_len];
}

const RSA_KEY_SIZE = 128;
const RSA_EXPONENT: u32 = 65537;

pub const Rsa = struct {
    pub const KeyPair = struct {
        n: [RSA_KEY_SIZE]u8,
        e: u32,
        d: [RSA_KEY_SIZE]u8,
        p: [RSA_KEY_SIZE / 2]u8,
        q: [RSA_KEY_SIZE / 2]u8,
    };

    keypair: KeyPair,

    pub fn generateKeys(_: std.mem.Allocator) !Rsa {
        var n_bytes: [RSA_KEY_SIZE]u8 = undefined;
        var d_bytes: [RSA_KEY_SIZE]u8 = undefined;
        var p_bytes: [RSA_KEY_SIZE / 2]u8 = undefined;
        var q_bytes: [RSA_KEY_SIZE / 2]u8 = undefined;

        std.crypto.random.bytes(&n_bytes);
        std.crypto.random.bytes(&d_bytes);
        std.crypto.random.bytes(&p_bytes);
        std.crypto.random.bytes(&q_bytes);

        return Rsa{
            .keypair = .{
                .n = n_bytes,
                .e = RSA_EXPONENT,
                .d = d_bytes,
                .p = p_bytes,
                .q = q_bytes,
            },
        };
    }

    pub fn publicKeyDer(self: *Rsa, allocator: std.mem.Allocator) ![]u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer buffer.deinit(allocator);

        try buffer.writer(allocator).writeByte(0x30);
        try buffer.writer(allocator).writeByte(0x82);
        try buffer.writer(allocator).writeByte(0x01);
        try buffer.writer(allocator).writeByte(0x22);

        const header_len: usize = 19;
        const mod_len: usize = RSA_KEY_SIZE;
        const total_len = header_len + mod_len + 3;

        try buffer.writer(allocator).writeInt(u16, @as(u16, @intCast(total_len)), .big);

        try buffer.writer(allocator).writeByte(0x30);
        try buffer.writer(allocator).writeByte(0x0D);
        try buffer.writer(allocator).writeByte(0x06);
        try buffer.writer(allocator).writeByte(0x09);
        try buffer.writer(allocator).writeAll(&[9]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01 });
        try buffer.writer(allocator).writeByte(0x05);
        try buffer.writer(allocator).writeByte(0x00);

        const pubkey_len: usize = mod_len + 3 + 11;
        try buffer.writer(allocator).writeByte(0x03);
        if (pubkey_len > 128) {
            try buffer.writer(allocator).writeByte(0x82);
        } else {
            try buffer.writer(allocator).writeByte(0x01);
        }
        try buffer.writer(allocator).writeInt(u16, @as(u16, @intCast(pubkey_len)), .big);
        try buffer.writer(allocator).writeByte(0x00);

        try buffer.writer(allocator).writeByte(0x02);
        try buffer.writer(allocator).writeByte(0x81);
        try buffer.writer(allocator).writeByte(@as(u8, @intCast(mod_len)));
        try buffer.writer(allocator).writeAll(&self.keypair.n);

        return buffer.items;
    }

    pub fn decrypt(_: *Rsa, output: []u8, input: []const u8) !void {
        if (input.len > output.len) {
            return error.OutputBufferTooSmall;
        }
        @memcpy(output[0..input.len], input);
    }

    pub fn verifyToken(_: *Rsa, token: []u8, expected: []const u8) !bool {
        if (token.len != expected.len) {
            return error.TokenMismatch;
        }
        return std.mem.eql(u8, token, expected);
    }
};

pub const AesCfb8Stream = struct {
    stream: std.net.Stream,
    aes_ctx: aes.Aes128,
    encrypt_feedback: [16]u8,
    decrypt_feedback: [16]u8,
    encrypt_pos: usize = 0,
    decrypt_pos: usize = 0,

    pub fn init(stream: std.net.Stream, shared_secret: []const u8) !AesCfb8Stream {
        var key: [16]u8 = undefined;
        var iv: [16]u8 = undefined;

        @memcpy(key[0..@min(16, shared_secret.len)], shared_secret[0..@min(16, shared_secret.len)]);
        @memcpy(iv[0..@min(16, shared_secret.len)], shared_secret[0..@min(16, shared_secret.len)]);

        if (shared_secret.len < 16) {
            for (key[shared_secret.len..], 0..) |*b, i| {
                b.* = @as(u8, @intCast(i));
            }
            for (iv[shared_secret.len..], 0..) |*b, i| {
                b.* = @as(u8, @intCast(i));
            }
        }

        return .{
            .stream = stream,
            .aes_ctx = aes.Aes128.init(key),
            .encrypt_feedback = iv,
            .decrypt_feedback = iv,
        };
    }

    pub fn reader(self: *AesCfb8Stream) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *AesCfb8Stream) Writer {
        return .{ .context = self };
    }

    pub const Reader = std.io.Reader(*AesCfb8Stream, std.net.Stream.ReadError, read);
    pub const Writer = std.io.Writer(*AesCfb8Stream, std.net.Stream.WriteError, write);

    fn encryptCfb8(self: *AesCfb8Stream, plaintext: u8, feedback: *[16]u8, pos: *usize) u8 {
        var encrypted_block: [16]u8 = undefined;
        self.aes_ctx.encrypt(&encrypted_block, feedback);
        const cipher_byte = plaintext ^ encrypted_block[0];
        feedback[0] = cipher_byte;
        pos.* += 1;
        return cipher_byte;
    }

    fn decryptCfb8(self: *AesCfb8Stream, ciphertext: u8, feedback: *[16]u8, pos: *usize) u8 {
        var encrypted_block: [16]u8 = undefined;
        self.aes_ctx.encrypt(&encrypted_block, feedback);
        const plaintext = ciphertext ^ encrypted_block[0];
        feedback[0] = ciphertext;
        pos.* += 1;
        return plaintext;
    }

    pub fn read(self: *AesCfb8Stream, buffer: []u8) std.net.Stream.ReadError!usize {
        const n = self.stream.read(buffer) catch return error.StreamIOError;
        for (buffer[0..n]) |*b| {
            b.* = self.decryptCfb8(b.*, &self.decrypt_feedback, &self.decrypt_pos);
        }
        return n;
    }

    pub fn write(self: *AesCfb8Stream, bytes: []const u8) std.net.Stream.WriteError!usize {
        var encrypted: std.ArrayList(u8) = .empty;
        defer encrypted.deinit();

        for (bytes) |b| {
            const cipher_byte = self.encryptCfb8(b, &self.encrypt_feedback, &self.encrypt_pos);
            try encrypted.append(cipher_byte);
        }

        return self.stream.write(encrypted.items);
    }
};
