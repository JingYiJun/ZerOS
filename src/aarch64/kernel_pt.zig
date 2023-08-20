const PAGE_SIZE = 4096;

// memory region attributes
const MT_DEVICE_nGnRnE = 0x0;
const MT_NORMAL = 0x1;
const MT_NORMAL_NC = 0x2;
const MT_DEVICE_nGnRnE_FLAGS = 0x00;
const MT_NORMAL_FLAGS = 0xFF; // Inner/Outer Write-Back Non-Transient RW-Allocate
const MT_NORMAL_NC_FLAGS = 0x44; // Inner/Outer Non-Cacheaconst

const SH_OUTER = 2 << 8;
const SH_INNER = 3 << 8;

const AF_USED = 1 << 10;

const PTE_NORMAL_NC = (MT_NORMAL_NC << 2) | AF_USED | SH_OUTER;
const PTE_NORMAL = (MT_NORMAL << 2) | AF_USED | SH_OUTER;
const PTE_DEVICE = (MT_DEVICE_nGnRnE << 2) | AF_USED;

const PTE_VALID = 0x1;

const PTE_TABLE = 0x3;
const PTE_BLOCK = 0x1;
const PTE_PAGE = 0x3;

const PTE_KERNEL = 0 << 6;
const PTE_USER = 1 << 6;
const PTE_RO = 1 << 7;
const PTE_RW = 0 << 7;

const PTE_KERNEL_DATA = PTE_KERNEL | PTE_NORMAL | PTE_BLOCK;
const PTE_KERNEL_DEVICE = PTE_KERNEL | PTE_DEVICE | PTE_BLOCK;
const PTE_USER_DATA = PTE_USER | PTE_NORMAL | PTE_PAGE;

const PTE_HIGH_NX = 1 << 54;

const KSPACE_MASK = 0xffff000000000000;

const N_PTE_PER_TABLE = 512;
const N_PTE_INTERVEL = 0x0020_0000;
const PTEntry = usize;
const PTEntries = [N_PTE_PER_TABLE]PTEntry;

pub var _kernel_pt_level3: PTEntries align(PAGE_SIZE) = _kernel_pt_level3_init: {
    var tmp: PTEntries = undefined;
    for (0..tmp.len) |i| {
        if (i < N_PTE_PER_TABLE - 8) {
            tmp[i] = (i * N_PTE_INTERVEL) | PTE_KERNEL_DATA;
        } else {
            tmp[i] = (i * N_PTE_INTERVEL) | PTE_KERNEL_DEVICE;
        }
    }
    break :_kernel_pt_level3_init tmp;
};

pub var _kernel_pt_level2: PTEntries align(PAGE_SIZE) =
    [_]PTEntry{
    0, // must set to &_kernel_pt_level3 + PTE_TABLE at runtime
    0x4000_0000 | PTE_KERNEL_DEVICE,
    0,
    0xC000_0000 | PTE_KERNEL_DEVICE,
} ++ [_]PTEntry{0} ** (N_PTE_PER_TABLE - 4);

pub var kernel_pt: PTEntries align(PAGE_SIZE) =
    [_]PTEntry{0} ** (N_PTE_PER_TABLE);
