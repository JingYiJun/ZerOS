// const kernel_pt_module = @import("aarch64/kernel_pt.zig");
const Arch = @import("aarch64/Arch.zig");
const UART = @import("driver/UART.zig");
const std = @import("std");
const builtin = @import("std").builtin;
// const kernel_pt_module = @import("aarch64/kernel_pt.zig");

// comptime {
//     @export(kernel_pt_module.kernel_pt, .{ .name = "kernel_pt", .linkage = .Strong });
//     @export(kernel_pt_module._kernel_pt_level2, .{ .name = "_kernel_pt_level2", .linkage = .Strong });
//     @export(kernel_pt_module._kernel_pt_level3, .{ .name = "_kernel_pt_level3", .linkage = .Strong });
// }

extern var __bss_start: usize;
extern var __bss_end: usize;

var hello: [16]u8 = undefined;

export fn main() noreturn {
    var cpu_id = Arch.cpu_id();
    // stop all other cpus.
    if (cpu_id != 0) {
        Arch.stop_cpu();
    }

    // clear bbs
    for (@intFromPtr(&__bss_start)..@intFromPtr(&__bss_end)) |p| {
        @as(*volatile u8, @ptrFromInt(p)).* = 0;
    }

    // init UART
    UART.init();

    // print hello world;
    @memcpy(hello[0..14], "hello, world!\n");
    UART.puts(&hello);

    // print current timestamp
    const current_timestamp = Arch.get_timestamp();
    UART.printf("{d}\n", .{current_timestamp});

    // print __bss_start
    UART.printf("&__bss_start = {p}; &__bss_end = {p}\n", .{ &__bss_start, &__bss_end });

    Arch.stop_cpu();
}

pub fn panic(_: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);
    Arch.stop_cpu();
}
