// const kernel_pt_module = @import("aarch64/kernel_pt.zig");
const Arch = @import("aarch64/Arch.zig");
const UART = @import("driver/UART.zig");
const builtin = @import("std").builtin;

// comptime {
//     @export(kernel_pt_module.kernel_pt, .{ .name = "kernel_pt", .linkage = .Strong });
//     @export(kernel_pt_module._kernel_pt_level2, .{ .name = "_kernel_pt_level2", .linkage = .Strong });
//     @export(kernel_pt_module._kernel_pt_level3, .{ .name = "_kernel_pt_level3", .linkage = .Strong });
// }

extern var __bss_start: usize;
extern var __bss_end: usize;

export fn main() noreturn {
    // stop all other cpus.
    if (Arch.cpu_id() != 0) {
        Arch.stop_cpu();
    }

    // clear bbs
    for (__bss_start..__bss_end) |p| {
        @as(*volatile u8, @ptrFromInt(p)).* = 0;
    }

    // init UART
    UART.init();

    // print hello world;
    UART.puts("Hello, world!");

    Arch.stop_cpu();
}

pub fn panic(_: []const u8, _: ?*builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);
    Arch.stop_cpu();
}
