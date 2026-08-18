-- Override normal-mode `P` to put from the yank register (register 0) after the
-- cursor, so `P` never pastes deleted text. Registered through yanky's own
-- `keys` spec (rather than an LspAttach autocmd) so lazy.nvim's key merge
-- cleanly replaces yanky's default normal-mode `P` (YankyPutBefore) when the
-- plugin loads, while leaving the visual-mode `P` mapping intact.
return {
    "gbprod/yanky.nvim",
    keys = {
        {
            "P",
            '"0<Plug>(YankyPutAfter)',
            mode = "n",
            remap = true,
            desc = "[P]ut from yank register (not delete)",
        },
    },
}
