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

    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();

    var decoded_bytes: usize = 0;
    var buf_counter: usize = 0;

    var buffer = [_]u8{0} ** 128;
    var buf_size = try file.readAll(&buffer);

    while (buf_counter + decoded_bytes <= buf_size) : (buf_counter += decoded_bytes) {
        var decoded = try decoder.decode8086Instruction(buffer[buf_counter..]);
        std.debug.print("{s}", .{decoder.mnemonicFromOperationType(decoded.Op)});

        std.debug.print(" ", .{});
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

        decoded_bytes = decoded.Size;
        if (decoded_bytes == 0) break;
    }
}
