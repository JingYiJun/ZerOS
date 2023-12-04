const Intrinsic = @This();

pub inline fn cpu_id() usize {
    // zig inline assembly is unstable right now, see https://github.com/ziglang/zig/issues/215
    // and https://ziglang.org/documentation/master/#Assembly
    // currently using https://llvm.org/docs/LangRef.html#inline-assembler-expressions
    // and https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html
    return asm volatile ("mrs %[ret], mpidr_el1"
        : [ret] "=r" (-> usize),
    ) & 0xff;
}

// instruct compiler not to reorder instructions around the fence.
pub inline fn compiler_fence() void {
    asm volatile ("" ::: "memory");
}

inline fn read_system_register(comptime name: []const u8) usize {
    return asm volatile ("mrs %[ret], " ++ name
        : [ret] "=r" (-> usize),
    );
}

pub inline fn get_clock_frequency() usize {
    return read_system_register("cntfrq_el0");
}

pub inline fn get_timestamp() usize {
    return read_system_register("cntpct_el0");
}

// set-event instruction.
pub inline fn sev() void {
    asm volatile ("sev" ::: "memory");
}

// wait-for-event instruction.
pub inline fn wfe() void {
    asm volatile ("wfe" ::: "memory");
}

pub inline fn stop_cpu() noreturn {
    while (true)
        wfe();
}

// for `device_get/put_*`, there's no need to protect them with architectual
// barriers, since they are intended to access device memory regions. These
// regions are already marked as nGnRnE in `kernel_pt`.

pub inline fn device_put_u32(addr: usize, value: u32) void {
    compiler_fence();
    @as(*volatile u32, @ptrFromInt(addr)).* = value;
    compiler_fence();
}

pub inline fn device_get_u32(addr: usize) u32 {
    compiler_fence();
    const result = @as(*volatile u32, @ptrFromInt(addr)).*;
    compiler_fence();
    return result;
}

pub fn delay_us(n: usize) void {
    const freq = get_clock_frequency();
    var end = get_timestamp();
    var now = end;
    end += freq / 1_000_000 * n;

    // see: https://github.com/ziglang/zig/issues/2159
    while (true) : (now = get_timestamp()) {
        if (now <= end) break;
    }
}
