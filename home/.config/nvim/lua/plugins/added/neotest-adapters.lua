return {
    -- JS/TS test adapters for neotest (neotest itself comes from the LazyVim test.core extra).
    -- Both adapters live in one file because order matters: neotest-vitest only claims
    -- projects with vitest installed, while neotest-bun claims any *.test.*/*.spec.* file,
    -- so vitest must be registered first or vitest projects would run through `bun test`.
    { "marilari88/neotest-vitest" },
    { "Arthur944/neotest-bun" },
    {
        "nvim-neotest/neotest",
        optional = true,
        opts = {
            adapters = { "neotest-vitest", "neotest-bun" },
        },
    },
}
