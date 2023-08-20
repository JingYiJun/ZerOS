const base = @import("base.zig");

pub const GPIO_BASE = base.MMIO_BASE + 0x0020_0000;

pub const GPFSEL0 = GPIO_BASE + 0x00;
pub const GPFSEL1 = GPIO_BASE + 0x04;
pub const GPFSEL2 = GPIO_BASE + 0x08;
pub const GPFSEL3 = GPIO_BASE + 0x0C;
pub const GPFSEL4 = GPIO_BASE + 0x10;
pub const GPFSEL5 = GPIO_BASE + 0x14;
pub const GPSET0 = GPIO_BASE + 0x1C;
pub const GPSET1 = GPIO_BASE + 0x20;
pub const GPCLR0 = GPIO_BASE + 0x28;
pub const GPLEV0 = GPIO_BASE + 0x34;
pub const GPLEV1 = GPIO_BASE + 0x38;
pub const GPEDS0 = GPIO_BASE + 0x40;
pub const GPEDS1 = GPIO_BASE + 0x44;
pub const GPHEN0 = GPIO_BASE + 0x64;
pub const GPHEN1 = GPIO_BASE + 0x68;
pub const GPPUD = GPIO_BASE + 0x94;
pub const GPPUDCLK0 = GPIO_BASE + 0x98;
pub const GPPUDCLK1 = GPIO_BASE + 0x9C;
