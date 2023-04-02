const std = @import("std");

pub fn main() anyerror!void {
    var gp = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gp.deinit();
    const allocator = gp.allocator();

    const file = try std.fs.cwd().openFile("single_register_mov", .{});
    defer file.close();

    const buf_size = 2000;
    const buffer = try file.readToEndAlloc(allocator, buf_size);
    defer allocator.free(buffer);

    const wide_regs = [8][]const u8{ "ax", "cx", "dx", "bx", "sp", "bp", "si", "di" };
    const regs = [8][]const u8{ "al", "cl", "dl", "bl", "ah", "ch", "dh", "bh" };
    const addy_calc = [8][]const u8{ "(bx) + (si)", "(bx) + (di)", "(bp) + (si)", "(bp) + (di)", "(si)", "(di)", "(bp)", "(bx)" };

    const stdout = std.io.getStdOut().writer();

    const short_op = @truncate(u4, buffer[0] >> 4);
    const long_op = @truncate(u6, buffer[0] >> 2);
    if (short_op == 0b1011) {
        const word = (buffer[0] & (1 << 3)) != 0;
        const reg = @truncate(u3, buffer[0]);
        const reg_name = if (word) wide_regs[reg] else regs[reg];
        const immediate = if (word) std.mem.bytesToValue(u16, buffer[1..3]) else buffer[1];
        try stdout.print("mov {s}, {d}", .{ reg_name, immediate });
    } else if (long_op == 0b100010) {
        const word = (buffer[0] & 1) != 0;
        const reg_is_destination = (buffer[0] & (1 << 1)) != 0;
        const mod = @truncate(u3, buffer[1] >> 6);
        const reg = @truncate(u3, buffer[1] >> 3);
        const reg_or_memory = @truncate(u3, buffer[1]);
        const reg_name = if (word) wide_regs[reg] else regs[reg];
        var rm_name: []const u8 = undefined;
        if (mod == 0b11) {
            rm_name = if (word) wide_regs[reg_or_memory] else regs[reg_or_memory];
        } else {
            var addy_str = std.ArrayList(u8).init(allocator);
            defer addy_str.deinit();
            if (mod == 0b00 and reg_or_memory == 0b110) {
                try addy_str.writer().print("{u}\n", .{std.mem.bytesToValue(u16, buffer[2..4])});
            } else {
                const addy = addy_calc[reg_or_memory];
                if (mod == 0b00) {
                    try addy_str.writer().print("{s}\n", .{addy});
                } else {
                    const disp = if (mod == 0b01) buffer[2] else std.mem.bytesToValue(u16, buffer[2..4]);
                    try addy_str.writer().print("{s} + {u}\n", .{ addy, disp });
                }
            }
            rm_name = addy_str.items;
        }

        const src = if (reg_is_destination) rm_name else reg_name;
        const dest = if (reg_is_destination) reg_name else rm_name;
        try stdout.print("mov {s}, {s}\n", .{ dest, src });
    } else {
        try stdout.print("I don't know what instruction this is...{x}\n", .{long_op});
    }
}
