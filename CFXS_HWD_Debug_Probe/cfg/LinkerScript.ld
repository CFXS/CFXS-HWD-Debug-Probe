/* Entry Point */
ENTRY(__cfxs_reset)

/* Memory Regions */
MEMORY {
    FLASH ( rx) : ORIGIN = 0x00000000, LENGTH = 1M
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 256K
}

/* Sections */
SECTIONS {
    .vector_table : {
        PROVIDE(__VECTOR_TABLE_START__ = .);
        . = ALIGN(4);
        KEEP(*(.vector_table));
        PROVIDE(__VECTOR_TABLE_END__ = .);
    } > FLASH

    .text : {
        PROVIDE(__TEXT_START__ = .);
        . = ALIGN(4);
        *(.text .text* .gnu.linkonce.t.* .glue_7 .glue_7t);
        . = ALIGN(4);
        KEEP(*(.init .fini));
        PROVIDE(__TEXT_END__ = .);
    } > FLASH

    .rodata : {
        PROVIDE(__RODATA_START__ = .);
        . = ALIGN(4);
        *(.rodata .rodata* .gnu.linkonce.r.*);
        PROVIDE(__RODATA_END__ = .);
    } > FLASH

    .ARM.extab : {
        . = ALIGN(4);
        *(.ARM.extab* .gnu.linkonce.armextab.*);
    } > FLASH

    .ARM : {
        PROVIDE_HIDDEN(__exidx_start = .);
        . = ALIGN(4);
        *(.ARM.exidx* .gnu.linkonce.armexidx.*);
        PROVIDE_HIDDEN(__exidx_end = .);
    } > FLASH

    .preinit_array : {
        PROVIDE(__PREINIT_ARRAY_START__ = .);
        . = ALIGN(4);
        KEEP(*(.preinit_array*));
        PROVIDE(__PREINIT_ARRAY_END__ = .);
    } > FLASH

    .init_array : {
        PROVIDE(__INIT_ARRAY_START__ = .);
        . = ALIGN(4);
        KEEP(*(SORT(.init_array.*)));
        KEEP(*(.init_array));
        PROVIDE(__INIT_ARRAY_END__ = .);
    } > FLASH

    .fini_array : {
        PROVIDE(__FINI_ARRAY_START__ = .);
        . = ALIGN(4);
        KEEP(*(SORT(.fini_array.*)));
        KEEP(*(.fini_array));
        PROVIDE(__FINI_ARRAY_END__ = .);
    } > FLASH

    .data : {
        PROVIDE(__DATA_START__ = .);
        . = ALIGN(4);
        *(.data .data*);
        *(.ram_func .ram_func*);
        PROVIDE(__DATA_END__ = .);
        PROVIDE(__NOINIT_START__ = .);
        . = ALIGN(4);
        *(.noinit .noinit*);
        PROVIDE(__NOINIT_END__ = .);
    } > RAM AT > FLASH

    .heap (NOLOAD) : {
        PROVIDE(__HEAP_START__ = .);
        . = . + 4096;
        PROVIDE(__HEAP_END__ = .);
    } > RAM

    .stack (NOLOAD) : {
        PROVIDE(__STACK_END__ = .);
        . = . + 16384;
        PROVIDE(__STACK_START__ = .);
    } > RAM

    .bss (NOLOAD) : {
        PROVIDE(__BSS_START__ = .);
        . = ALIGN(4);
        *(.bss .bss* COMMON);
        PROVIDE(__BSS_END__ = .);
    } > RAM

    .ARM.attributes 0 : { *(.ARM.attributes) }
}

/* Section Range Defines */
PROVIDE(__CONST_VECTOR_TABLE_START__ = LOADADDR(.vector_table));
PROVIDE(__CONST_VECTOR_TABLE_END__ = LOADADDR(.vector_table) + SIZEOF(.vector_table));
PROVIDE(__CONST_VECTOR_TABLE_SIZE__ = SIZEOF(.vector_table));
PROVIDE(__CONST_TEXT_START__ = LOADADDR(.text));
PROVIDE(__CONST_TEXT_END__ = LOADADDR(.text) + SIZEOF(.text));
PROVIDE(__CONST_TEXT_SIZE__ = SIZEOF(.text));
PROVIDE(__CONST_RODATA_START__ = LOADADDR(.rodata));
PROVIDE(__CONST_RODATA_END__ = LOADADDR(.rodata) + SIZEOF(.rodata));
PROVIDE(__CONST_RODATA_SIZE__ = SIZEOF(.rodata));
PROVIDE(__CONST_ARM_START__ = LOADADDR(.ARM));
PROVIDE(__CONST_ARM_END__ = LOADADDR(.ARM) + SIZEOF(.ARM));
PROVIDE(__CONST_ARM_SIZE__ = SIZEOF(.ARM));
PROVIDE(__CONST_PREINIT_ARRAY_START__ = LOADADDR(.preinit_array));
PROVIDE(__CONST_PREINIT_ARRAY_END__ = LOADADDR(.preinit_array) + SIZEOF(.preinit_array));
PROVIDE(__CONST_PREINIT_ARRAY_SIZE__ = SIZEOF(.preinit_array));
PROVIDE(__CONST_INIT_ARRAY_START__ = LOADADDR(.init_array));
PROVIDE(__CONST_INIT_ARRAY_END__ = LOADADDR(.init_array) + SIZEOF(.init_array));
PROVIDE(__CONST_INIT_ARRAY_SIZE__ = SIZEOF(.init_array));
PROVIDE(__CONST_FINI_ARRAY_START__ = LOADADDR(.fini_array));
PROVIDE(__CONST_FINI_ARRAY_END__ = LOADADDR(.fini_array) + SIZEOF(.fini_array));
PROVIDE(__CONST_FINI_ARRAY_SIZE__ = SIZEOF(.fini_array));
PROVIDE(__CONST_DATA_START__ = LOADADDR(.data));
PROVIDE(__CONST_DATA_END__ = LOADADDR(.data) + SIZEOF(.data));
PROVIDE(__CONST_DATA_SIZE__ = SIZEOF(.data));

/* Memory Region Range Defines */
PROVIDE(__REGION_FLASH_START__ = ORIGIN(FLASH));
PROVIDE(__REGION_FLASH_END__ = ORIGIN(FLASH) + LENGTH(FLASH));
PROVIDE(__REGION_FLASH_SIZE__ = LENGTH(FLASH));
PROVIDE(__REGION_RAM_START__ = ORIGIN(RAM));
PROVIDE(__REGION_RAM_END__ = ORIGIN(RAM) + LENGTH(RAM));
PROVIDE(__REGION_RAM_SIZE__ = LENGTH(RAM));
