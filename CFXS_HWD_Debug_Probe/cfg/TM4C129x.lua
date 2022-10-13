return {
    EntryPoint = "__cfxs_reset",

    Memory = {
        ["FLASH"] = { permissions = "r-x", start = 0x00000000, size = 1 * MB },
        ["RAM"]   = { permissions = "rwx", start = 0x20000000, size = 256 * kB },

        Alias = {}
    },

    Stack = {
        location = "RAM",
        size = 8 * kB
    },

    NoDefaultSections = false,
    Sections = {
        {
            name = "heap",
            location = "RAM",
            target = "RAM",
            type = NO_LOAD,
            content = {
                Define("__HEAP_START__"),
                Extend(4 * kB),
                Define("__HEAP_END__"),
            }
        },
        {
            name = "stack",
            location = "RAM",
            target = "RAM",
            type = NO_LOAD,
            content = {
                Define("__STACK_END__"),
                Extend(16 * kB),
                Define("__STACK_START__"),
            }
        },
    },

    -- Discard = {
    --     ["libc.a"] = {},
    --     ["libm.a"] = {},
    --     ["libgcc.a"] = {},
    -- }
}
