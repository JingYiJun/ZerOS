const std = @import("std");

const GPIO = @import("GPIO.zig");
const base = @import("base.zig");
const Arch = @import("../aarch64/Arch.zig");
const device_get_u32 = Arch.device_get_u32;
const device_put_u32 = Arch.device_put_u32;
const delay_us = Arch.delay_us;

const AUX_BASE = base.MMIO_BASE + 0x215000;

const AUX_ENABLES = AUX_BASE + 0x04;
const AUX_MU_IO_REG = AUX_BASE + 0x40;
const AUX_MU_IER_REG = AUX_BASE + 0x44;
const AUX_MU_IIR_REG = AUX_BASE + 0x48;
const AUX_MU_LCR_REG = AUX_BASE + 0x4C;
const AUX_MU_MCR_REG = AUX_BASE + 0x50;
const AUX_MU_LSR_REG = AUX_BASE + 0x54;
const AUX_MU_MSR_REG = AUX_BASE + 0x58;
const AUX_MU_SCRATCH = AUX_BASE + 0x5C;
const AUX_MU_CNTL_REG = AUX_BASE + 0x60;
const AUX_MU_STAT_REG = AUX_BASE + 0x64;
const AUX_MU_BAUD_REG = AUX_BASE + 0x68;

const AUX_UART_CLOCK = 250000000;

fn AUX_MU_BAUD(comptime baudrate: comptime_int) comptime_int {
    return (AUX_UART_CLOCK / (baudrate * 8)) - 1;
}

pub fn init() void {
    // enable pins 14 and 15
    device_put_u32(GPIO.GPPUD, 0);
    delay_us(5);
    device_put_u32(GPIO.GPPUDCLK0, (1 << 14) | (1 << 15));
    delay_us(5);
    device_put_u32(GPIO.GPPUDCLK0, 0);

    // enable mini uart and access to its registers.
    device_put_u32(AUX_ENABLES, 1);
    // disable auto flow control, receiver and transmitter (for now).
    device_put_u32(AUX_MU_CNTL_REG, 0);
    // enable receiving interrupts.
    device_put_u32(AUX_MU_IER_REG, 3 << 2 | 1);
    // enable 8-bit mode.
    device_put_u32(AUX_MU_LCR_REG, 3);
    // set RTS line to always high.
    device_put_u32(AUX_MU_MCR_REG, 0);
    // set baud rate to 115200.
    device_put_u32(AUX_MU_BAUD_REG, AUX_MU_BAUD(115200));
    // clear receive and transmit FIFO.
    device_put_u32(AUX_MU_IIR_REG, 6);
    // finally, enable receiver and transmitter.
    device_put_u32(AUX_MU_CNTL_REG, 3);

    // set_interrupt_handler(IRQ_AUX, uart_intr);
}

pub fn get_char() u8 {
    const state = device_get_u32(AUX_MU_IIR_REG);
    if ((state & 1) || (state & 6) != 4)
        return (u8) - 1;

    return device_get_u32(AUX_MU_IO_REG) & 0xff;
}

pub fn put_char(c: u8) void {
    while (device_get_u32(AUX_MU_LSR_REG) & 0x20 == 0) {}

    device_put_u32(AUX_MU_IO_REG, c);

    // fix Windows's '\r'.
    if (c == '\n')
        put_char('\r');
}

pub fn puts(s: []const u8) void {
    for (s) |c| {
        put_char(c);
    }
}

var buf: [512]u8 = undefined;

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    const buf_print_to = std.fmt.bufPrint(&buf, fmt, args) catch |err| {
        @panic(@errorName(err));
    };
    puts(buf_print_to);
}
