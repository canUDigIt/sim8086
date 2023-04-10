const std = @import("std");

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    const file = try std.fs.cwd().openFile("more_movs", .{});
    defer file.close();

    const wide_regs = [8][]const u8{ "ax", "cx", "dx", "bx", "sp", "bp", "si", "di" };
    const regs = [8][]const u8{ "al", "cl", "dl", "bl", "ah", "ch", "dh", "bh" };
    const addy_calc = [8][]const u8{ "(bx) + (si)", "(bx) + (di)", "(bp) + (si)", "(bp) + (di)", "(si)", "(di)", "(bp)", "(bx)" };

    var decoded_bytes: usize = 1;
    var buf_counter: usize = 0;

    var buffer = [_]u8{0} ** 128;
    var buf_size = try file.readAll(&buffer);

    var string_buffer = [_]u8{0} ** 32;

    while (buf_counter + decoded_bytes <= buf_size) : (buf_counter += decoded_bytes) {
        var buf_ptr: [*]const u8 = &buffer;
        buf_ptr += buf_counter;
        const short_op = @truncate(u4, buf_ptr[0] >> 4);
        const long_op = @truncate(u6, buf_ptr[0] >> 2);
        if (short_op == 0b1011) {
            const word = (buf_ptr[0] & (1 << 3)) != 0;
            const reg = @truncate(u3, buf_ptr[0]);
            const reg_name = if (word) wide_regs[reg] else regs[reg];
            const immediate = if (word) std.mem.bytesToValue(i16, buf_ptr[1..3]) else @bitCast(i8, buf_ptr[1]);
            decoded_bytes = if (word) 3 else 2;
            try stdout.print("mov {s}, {d}\n", .{ reg_name, immediate });
        } else if (long_op == 0b100010) {
            const word = (buf_ptr[0] & 1) != 0;
            const reg_is_destination = (buf_ptr[0] & (1 << 1)) != 0;
            const mod = @truncate(u3, buf_ptr[1] >> 6);
            const reg = @truncate(u3, buf_ptr[1] >> 3);
            const reg_or_memory = @truncate(u3, buf_ptr[1]);
            const reg_name = if (word) wide_regs[reg] else regs[reg];
            decoded_bytes = 2;
            var rm_name: []const u8 = undefined;
            if (mod == 0b11) {
                rm_name = if (word) wide_regs[reg_or_memory] else regs[reg_or_memory];
            } else {
                if (mod == 0b00 and reg_or_memory == 0b110) {
                    decoded_bytes = 4;
                    rm_name = try std.fmt.bufPrint(&string_buffer, "{d}", .{std.mem.bytesToValue(i16, buf_ptr[2..4])});
                } else {
                    const addy = addy_calc[reg_or_memory];
                    if (mod == 0b00) {
                        rm_name = try std.fmt.bufPrint(&string_buffer, "{s}", .{addy});
                    } else {
                        const disp_8bit = mod == 0b01;
                        const disp = if (disp_8bit) @bitCast(i8, buf_ptr[2]) else std.mem.bytesToValue(i16, buf_ptr[2..4]);
                        decoded_bytes = if (disp_8bit) 3 else 4;
                        rm_name = try std.fmt.bufPrint(&string_buffer, "{s} + {d}", .{ addy, disp });
                    }
                }
            }

            const src = if (reg_is_destination) rm_name else reg_name;
            const dest = if (reg_is_destination) reg_name else rm_name;
            try stdout.print("mov {s}, {s}\n", .{ dest, src });
        } else {
            try stdout.print("I don't know what instruction this is...{b}\n", .{long_op});
        }
    }
}
