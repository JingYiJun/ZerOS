OUTPUT_ARCH(aarch64)
ENTRY(_start)
BASE_ADDRESS = 0xFFFF000000080000;

SECTIONS
{
    . = BASE_ADDRESS;
    
    .text : ALIGN(4K) {
        PROVIDE(__text_start = .);
        KEEP(*(.text.boot))
        *(.text .text.*)
    }


    .rodata : ALIGN(4K) { 
        PROVIDE(__text_end = .);
        PROVIDE(__rodata_start = .);
        *(.rodata .rodata.*) 

        /* KEEP(*(.debug_info))
        KEEP(*(.debug_abbrev))
        KEEP(*(.debug_aranges))
        KEEP(*(.debug_line))
        KEEP(*(.debug_str))
        KEEP(*(.debug_ranges))
        KEEP(*(.debug_pubnames))
        KEEP(*(.debug_pubtypes))
        KEEP(*(.debug_frame)) */
    }

    
    .data : ALIGN(4K) { 
        PROVIDE(__rodata_end = .);
        PROVIDE(__data_start = .);
        *(.data .data.*)
    }
    
    .bss : ALIGN(4K) { 
        PROVIDE(__data_end = .);
        PROVIDE(__bss_start = .);
        *(.bss .bss.*)
        PROVIDE(__bss_end = .);
    }

    /DISCARD/ : {
        *(.eh_frame)
    }
}
