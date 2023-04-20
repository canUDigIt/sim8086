const std = @import("std");
const decoder = @import("sim86_shared.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.log.err("Usage: {s} INST_BINARY_FILE", .{args[0]});
        return;
    }

    var print = false;

    var registers = std.StringHashMap(i16).init(allocator);

    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();

    var decoded_bytes: usize = 0;
    var buf_counter: usize = 0;

    var buffer = [_]u8{0} ** 128;
    var buf_size = try file.readAll(buffer[0..]);

    while (buf_counter + decoded_bytes <= buf_size) : (buf_counter += decoded_bytes) {
        var decoded = try decoder.decode8086Instruction(buffer[buf_counter..]);
        if (print) {
            std.debug.print("{s} ", .{decoder.mnemonicFromOperationType(decoded.Op)});

            for (decoded.Operands) |*operand| {
                switch (@intToEnum(decoder.OperandType, operand.Type)) {
                    .OperandNone => {},
                    .OperandRegister => {
                        const name = decoder.registerNameFromOperand(&operand.unnamed_0.Register);
                        std.debug.print("{s}", .{name});
                    },
                    .OperandMemory => {
                        var address = operand.unnamed_0.Address;
                        const term1 = decoder.registerNameFromOperand(&address.Terms[0].Register);
                        const term2 = decoder.registerNameFromOperand(&address.Terms[1].Register);
                        std.debug.print("[{s} + {s} + {d}]", .{ term1, term2, address.Displacement });
                    },
                    .OperandImmediate => {
                        std.debug.print("{d}", .{operand.unnamed_0.Immediate.Value});
                    },
                }
                std.debug.print(" ", .{});
            }
            std.debug.print("\n", .{});
        } else {
            if (decoded.Op == 1) {
                const reg = decoder.registerNameFromOperand(&decoded.Operands[0].unnamed_0.Register);
                const value = switch (@intToEnum(decoder.OperandType, decoded.Operands[1].Type)) {
                    .OperandNone => 0,
                    .OperandRegister => blk: {
                        const name = decoder.registerNameFromOperand(&decoded.Operands[1].unnamed_0.Register);
                        break :blk registers.get(name) orelse 0;
                    },
                    .OperandMemory => blk: {
                        var address = decoded.Operands[1].unnamed_0.Address;
                        const term1 = decoder.registerNameFromOperand(&address.Terms[0].Register);
                        const term2 = decoder.registerNameFromOperand(&address.Terms[1].Register);
                        const val1 = registers.get(term1) orelse 0;
                        const val2 = registers.get(term2) orelse 0;
                        break :blk val1 + val2 + @truncate(i16, address.Displacement);
                    },
                    .OperandImmediate => @truncate(i16, decoded.Operands[1].unnamed_0.Immediate.Value),
                };
                try registers.put(reg, value);
            }
        }

        decoded_bytes = decoded.Size;
        if (decoded_bytes == 0) break;
    }

    // TODO: print out the registers if !print
    if (!print) {
        var keys = registers.keyIterator();
        while (keys.next()) |key| {
            std.debug.print("{s}: {d}\n", .{ key.*, registers.get(key.*) orelse 0 });
        }
    }
}
