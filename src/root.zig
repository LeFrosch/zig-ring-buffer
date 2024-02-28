const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const mem = std.mem;

const assert = std.debug.assert;

pub fn RingBuffer(comptime pages: usize) type {
    return struct {
        const Self = @This();
        const Len = mem.page_size * pages;

        fd: os.fd_t,
        buffer: []align(mem.page_size) u8,

        pub fn init() !Self {
            const fd = try os.memfd_create("buffer_file", os.FD_CLOEXEC);
            errdefer os.close(fd);

            try os.ftruncate(fd, Len);

            const buffer = try os.mmap(
                null,
                Len * 2,
                os.PROT.NONE,
                .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
                -1,
                0,
            );
            errdefer os.munmap(buffer);

            const region1 = try os.mmap(
                buffer.ptr,
                Len,
                os.PROT.WRITE | os.PROT.READ,
                .{ .TYPE = .SHARED, .FIXED = true },
                fd,
                0,
            );
            if (region1.ptr != buffer.ptr) return error.InvalidRegionPtr;

            const region2 = try os.mmap(
                buffer.ptr + Len,
                Len,
                os.PROT.WRITE | os.PROT.READ,
                .{ .TYPE = .SHARED, .FIXED = true },
                fd,
                0,
            );
            if (region2.ptr != buffer.ptr + Len) return error.InvalidRegionPtr;

            return .{
                .fd = fd,
                .buffer = buffer,
            };
        }

        pub fn deinit(self: Self) void {
            os.munmap(self.buffer);
            os.close(self.fd);
        }

        pub fn slice(self: Self, offset: usize, length: usize) []u8 {
            assert(length <= Len);

            const real_offset = offset % Len;
            return self.buffer[real_offset .. real_offset + length];
        }
    };
}

test "write to buffer" {
    const Buffer = RingBuffer(1);
    const buffer = try Buffer.init();

    for (0..20) |i| {
        buffer.slice(Buffer.Len * i + i, 1)[0] = @as(u8, @intCast(i));
    }

    for (0..20) |i| {
        try std.testing.expectEqual(buffer.slice(i, 1)[0], @as(u8, @intCast(i)));
    }
}
