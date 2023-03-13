const std = @import("std");

pub fn main() anyerror!void {
    const Instruction = packed struct {
        word: bool,
        reg_is_destination: bool,
        opcode: u6,
        register_memory: u3,
        reg: u3,
        mode: u2,
    };

    const file = try std.fs.cwd().openFile("single_register_mov", .{});
    defer file.close();

    var buffer: [2]u8 = undefined;
    try file.seekTo(0);
    _ = try file.readAll(&buffer);
    var encoded_inst = @bitCast(Instruction, buffer);

    const wide_regs = [8]*const [2:0]u8{ "ax", "cx", "dx", "bx", "sp", "bp", "si", "di" };
    // var regs = [8][2:0]u8{"al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"};
    const stdout = std.io.getStdOut().writer();
    if (buffer[0] == 0x89) {
        const destination = if (encoded_inst.reg_is_destination) wide_regs[encoded_inst.reg] else wide_regs[encoded_inst.register_memory];
        const source = if (encoded_inst.reg_is_destination) wide_regs[encoded_inst.register_memory] else wide_regs[encoded_inst.reg];
        try stdout.print("mov {s}, {s}\n", .{ destination, source });
    } else {
        try stdout.print("I don't know what instruction this is...{x}\n", .{encoded_inst.opcode});
    }
}
