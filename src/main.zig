const std = @import("std");

const RegisterMemoryMov = packed struct {
    word: bool,
    reg_is_destination: bool,
    opcode: u6,
    register_memory: u3,
    reg: u3,
    mod: u2,
};

const ImmediateToRegMov = packed struct { reg: u3, word: bool, opcode: u4 };

pub fn main() anyerror!void {
    const file = try std.fs.cwd().openFile("single_register_mov", .{});
    defer file.close();

    var buffer: []u8 = undefined;
    try file.seekTo(0);
    _ = try file.readAll(buffer);
    var encoded_inst = @bitCast(RegisterMemoryMov, buffer);
    var immediate_mov = @bitCast(ImmediateToRegMov, buffer[0]);

    const wide_regs = [8][]const u8{ "ax", "cx", "dx", "bx", "sp", "bp", "si", "di" };
    const regs = [8][]const u8{ "al", "cl", "dl", "bl", "ah", "ch", "dh", "bh" };
    const addy_calc = [8][]const u8{ "(bx) + (si)", "(bx) + (di)", "(bp) + (si)", "(bp) + (di)", "(si)", "(di)", "(bp)", "(bx)" };

    const stdout = std.io.getStdOut().writer();
    if (immediate_mov.opcode == 0b1011) {
        const reg = if (immediate_mov.word) wide_regs[immediate_mov.reg] else regs[immediate_mov.reg];
        const immediate = if (immediate_mov.word) @bitCast(u16, buffer[1]) else @bitCast(u8, buffer[1]);
        try stdout.print("mov {s}, {d}", .{ reg, immediate });
    } else if (encoded_inst.opcode == 0b100010) {
        const reg = if (encoded_inst.word) wide_regs[encoded_inst.reg] else regs[encoded_inst.reg];
        const reg_or_memory = if (encoded_inst.mod == 0b11) {
            if (encoded_inst.word) wide_regs[encoded_inst.register_memory] else reg[encoded_inst.register_memory];
        } else {
            if (encoded_inst.mod == 0b00 and encoded_inst.register_memory == 0b110) {
                @bitCast(u16, buffer[2]);
            } else {
                const addy = addy_calc[encoded_inst.register_memory];
                if (encoded_inst.mod == 0b00) {
                    addy;
                } else {
                    var addy_str: []u8 = undefined;
                    const disp = if (encoded_inst.mod == 0b01) @bitCast(u8, buffer[2]) else @bitCast(u16, buffer[2]);
                    std.fmt.bufPrint(addy_str, "{s} + {s}", .{ addy, disp });
                    addy_str;
                }
            }
        };

        const args = if (encoded_inst.reg_is_destination) {
            .{ reg_or_memory, reg };
        } else {
            .{ reg, reg_or_memory };
        };
        try stdout.print("mov {s}, {s}\n", args);
    } else {
        try stdout.print("I don't know what instruction this is...{x}\n", .{encoded_inst.opcode});
    }
}
