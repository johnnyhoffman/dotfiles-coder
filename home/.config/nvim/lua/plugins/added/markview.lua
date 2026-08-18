---@module "markview"

-- TODO https://github.com/OXY2DEV/nvim/blob/main/lua/scripts/lsp_hover.lua
-- TODO https://github.com/OXY2DEV/markview.nvim/blob/c81ce9ed129387fc5fdec91abe9818a1b0e6fcac/doc/markview.nvim-extras.txt#L8
return {
    "OXY2DEV/markview.nvim",
    lazy = false,
    dependencies = { "saghen/blink.cmp" },
    opts = function()
        -- Blend two packed 0xRRGGBB colors. `ratio` is the weight of `c1`
        -- (so blend(fg, bg, 0.7) = 70% fg, 30% bg).
        local function blend(c1, c2, ratio)
            local r1, g1, b1 = bit.rshift(c1, 16), bit.band(bit.rshift(c1, 8), 0xff), bit.band(c1, 0xff)
            local r2, g2, b2 = bit.rshift(c2, 16), bit.band(bit.rshift(c2, 8), 0xff), bit.band(c2, 0xff)
            local r = math.floor(r1 * ratio + r2 * (1 - ratio))
            local g = math.floor(g1 * ratio + g2 * (1 - ratio))
            local b = math.floor(b1 * ratio + b2 * (1 - ratio))
            return bit.lshift(r, 16) + bit.lshift(g, 8) + b
        end

        -- Fallback editor background when `Normal` has no `bg` (Catppuccin Mocha base).
        local FALLBACK_BG = 0x1e1e2e

        local function customize_heading_highlights()
            for i = 1, 6 do
                -- MarkviewHeading1-6 are links to MarkviewPalette1-6, so the palette groups need to be modified
                local palette_name = "MarkviewPalette" .. i
                local hl = vim.api.nvim_get_hl(0, { name = palette_name, link = false })
                if next(hl) then
                    if i <= 3 then
                        hl.bold = true
                        ---@diagnostic disable-next-line: param-type-mismatch
                        vim.api.nvim_set_hl(0, palette_name, hl)
                    end
                    -- Create folded variants (italic + slightly dimmed)
                    local folded_hl = vim.deepcopy(hl)
                    folded_hl.italic = true
                    if folded_hl.fg then
                        -- Blend toward background slightly for dimmed effect
                        local bg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg or FALLBACK_BG
                        folded_hl.fg = blend(folded_hl.fg, bg, 0.7)
                    end
                    ---@diagnostic disable-next-line: param-type-mismatch
                    vim.api.nvim_set_hl(0, "MarkviewHeading" .. i .. "Folded", folded_hl)
                end
            end
        end

        -- Custom foldtext that preserves heading styling when folded
        function _G.MarkviewFoldText()
            local line = vim.fn.getline(vim.v.foldstart)
            local level = line:match("^(#+)")
            if level then
                local h = #level
                local fold_count = vim.v.foldend - vim.v.foldstart + 1
                local heading_text = line:gsub("^#+%s*", "")
                return {
                    { string.rep(" ", h - 1) .. "▸ ", "MarkviewHeading" .. h .. "Folded" },
                    { heading_text, "MarkviewHeading" .. h .. "Folded" },
                    { " (" .. fold_count .. " lines)", "Comment" },
                }
            end
            return vim.fn.foldtext()
        end
        vim.opt.foldtext = "v:lua.MarkviewFoldText()"

        -- Reversed (fg<->bg swapped) variants of the checkbox marker highlights, so the
        -- rendered `[-]`/`[?]` markers read as filled badges while the task text (driven
        -- by scope_hl) is untouched. The marker's fg color becomes its background and the
        -- editor background becomes the glyph color.
        local function customize_checkbox_highlights()
            local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
            local function make_reverse(name, source)
                local src = vim.api.nvim_get_hl(0, { name = source, link = false })
                if src and src.fg then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    vim.api.nvim_set_hl(0, name, { fg = normal.bg, bg = src.fg })
                end
            end
            make_reverse("MarkviewCheckboxCancelledReverse", "MarkviewPalette0Fg")
            make_reverse("MarkviewCheckboxPendingReverse", "MarkviewPalette2Fg")
            make_reverse("MarkviewCheckboxImportantReverse", "MarkviewPalette1Fg")
            make_reverse("MarkviewCheckboxStarredReverse", "MarkviewPalette3Fg")
            make_reverse("MarkviewCheckboxInfoReverse", "MarkviewPalette6Fg")
            make_reverse("MarkviewCheckboxQuoteReverse", "MarkviewPalette0Fg")
            -- note (`:`) — uses the otherwise-unused Palette4
            make_reverse("MarkviewCheckboxNoteReverse", "MarkviewPalette4Fg")
            -- unchecked — reversed so the empty box reads as a filled badge too. Source
            -- from the palette group (what MarkviewCheckboxUnchecked links to) rather than
            -- the markview-internal group, which isn't reliably defined when this runs.
            make_reverse("MarkviewCheckboxUncheckedReverse", "MarkviewPalette1Fg")
            -- cancelled (`-`) keeps a strikethrough on the task text but does NOT recolor it,
            -- so any bold/italic/links underneath stay intact (markview's CheckboxStriked
            -- also greys the text, which flattens that formatting).
            vim.api.nvim_set_hl(0, "MarkviewCheckboxStrikeOnly", { strikethrough = true })

            -- Dimmed variants for the resolved "+x" markers (`[?x]`, `[!x]`, …): the same
            -- style as the open marker, but blended toward the editor background so the
            -- resolved item recedes visually. For filled badges the fill is dimmed (glyph
            -- stays the editor bg color so it still punches through); for fg-only markers
            -- the glyph color itself is dimmed.
            local bg = normal.bg or FALLBACK_BG
            local function fg_of(group)
                local h = vim.api.nvim_get_hl(0, { name = group, link = false })
                return h and h.fg
            end
            -- Dimmed filled badge: fg = editor bg, bg = source color blended toward bg.
            local function make_reverse_dim(name, source)
                local fg = fg_of(source)
                if fg then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    vim.api.nvim_set_hl(0, name, { fg = bg, bg = blend(fg, bg, 0.45) })
                end
            end
            -- Dimmed foreground: glyph/text color blended toward bg.
            local function make_fg_dim(name, source)
                local fg = fg_of(source)
                if fg then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    vim.api.nvim_set_hl(0, name, { fg = blend(fg, bg, 0.55) })
                end
            end

            -- Dimmed text colors for the non-reversed resolved markers. Sourced from the
            -- palette groups (each marker's actual color) rather than the markview-internal
            -- Checkbox* groups, which aren't reliably defined when this runs (Important/Info
            -- aren't defined by markview at all) — so the entries fell back to plain text.
            make_fg_dim("MarkviewCheckboxPendingDim", "MarkviewPalette2Fg")
            make_fg_dim("MarkviewCheckboxImportantDim", "MarkviewPalette1Fg")
            make_fg_dim("MarkviewCheckboxInfoDim", "MarkviewPalette6Fg")
            make_fg_dim("MarkviewPalette4FgDim", "MarkviewPalette4Fg")

            -- Foreground-only markers (rescheduled `>`, deferred `<`).
            make_fg_dim("MarkviewPalette5FgDim", "MarkviewPalette5Fg")
            make_fg_dim("MarkviewPalette7FgDim", "MarkviewPalette7Fg")
        end

        -- Enable multi-character checkbox markers (e.g. `- [?x]`).
        -- markview assumes a *single* character inside the brackets for checkboxes, in two
        -- independent parsers, so two patches are needed:
        --   1. markdown_inline.shortcut_link — without this, `[?x]` is parsed as a markdown
        --      shortcut link and rendered as a link. We reroute multi-char bracket content
        --      on a list item to the checkbox parser, which produces the badge. The renderer
        --      keys off the literal bracket content (`spec.get({ state })`), so a `["?x"]`
        --      entry in `checkboxes` below is all that's needed to style it.
        --   2. markdown.list_item — the block parser captures `checkbox` via `%[(.)%]`
        --      (single char), so for `[?x]` it sees no checkbox and therefore won't conceal
        --      the leading bullet or apply the scope highlight. We fix up the parsed item's
        --      `checkbox` field with the full multi-char content.
        -- Both patches are idempotent (sentinel flags) and survive plugin reloads.
        local function enable_multichar_checkboxes()
            local ok_inline, inline = pcall(require, "markview.parsers.markdown_inline")
            if
                ok_inline
                and not inline._multichar_checkbox_patched
                and type(inline.shortcut_link) == "function"
                and type(inline.checkbox) == "function"
            then
                inline._multichar_checkbox_patched = true

                local orig_shortcut_link = inline.shortcut_link
                inline.shortcut_link = function(buffer, node, text, range)
                    local line = vim.api.nvim_buf_get_lines(buffer, range.row_start, range.row_start + 1, false)[1]
                        or ""
                    local before = line:sub(0, range.col_start)
                    local is_list = before:match("^[%s>]*[-+*]%s+$") or before:match("^[%s>]*%d+[.)]%s+$")
                    -- `^%[..+%]$` = brackets around two-or-more chars (single char is handled upstream)
                    if is_list and type(text[1]) == "string" and text[1]:match("^%[..+%]$") then
                        return inline.checkbox(buffer, node, text, range)
                    end
                    return orig_shortcut_link(buffer, node, text, range)
                end
            end

            local ok_md, md = pcall(require, "markview.parsers.markdown")
            if ok_md and not md._multichar_checkbox_patched and type(md.list_item) == "function" then
                md._multichar_checkbox_patched = true

                local orig_list_item = md.list_item
                md.list_item = function(buffer, node, x, range)
                    orig_list_item(buffer, node, x, range)
                    -- Backfill multi-char checkbox content the upstream `%[(.)%]` missed.
                    local item = md.content and md.content[#md.content]
                    if item and item.class == "markdown_list_item" and not item.checkbox then
                        local first = (item.text and item.text[1]) or ""
                        local mc = first:match("^[%>%s]*[%-%+%*]%s+%[([^%]]+)%]")
                            or first:match("^[%>%s]*%d+[%.%)]%s+%[([^%]]+)%]")
                        if mc and #mc >= 2 then
                            item.checkbox = mc
                        end
                    end
                end
            end
        end

        -- must run after markview creates its highlights, and again on colorscheme change
        customize_heading_highlights()
        customize_checkbox_highlights()
        enable_multichar_checkboxes()
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = vim.api.nvim_create_augroup("MarkviewHighlightGroupCustomization", { clear = true }),
            callback = function()
                customize_heading_highlights()
                customize_checkbox_highlights()
            end,
        })

        local signs = { "█", "🮿", "🮘", "𜱄", "𜱀", "=" }

        ---@param h integer
        ---@return markview.config.markdown.headings.atx
        local function make_heading_definition(h)
            if h < 1 or h > 6 then
                return {}
            end
            local sign_hl = "MarkviewHeading" .. h .. "Sign"
            local hl = "MarkviewHeading" .. h

            local prefix = signs[h]
            -- for i = 1, h do
            --     prefix = prefix .. (i == h and (h <= 3 and "🭬" or "🯛") or signs[h])
            -- end
            for i = 1, h do
                prefix = prefix .. (i == 1 and (h <= 3 and "🭬" or "🯛") or " ")
            end

            return {
                style = "icon",
                sign = signs[h],
                sign_hl = sign_hl,
                icon = prefix,
                icon_hl = sign_hl,
                hl = hl,
                align = "left",
            }
        end

        ---@type markview.config
        local result = {
            preview = {
                filetypes = { "markdown" },
                ignore_buftypes = {},
                modes = { "n", "no", "c" },
                hybrid_modes = vim.g.markview_use_hybrid_mode and { "n" } or {},
                -- helps paericularly with revealing codeblock fences while cursor is within the codeblock
                linewise_hybrid_mode = false,
            },
            ---@diagnostic disable: missing-fields
            markdown = {
                -- a modified `require("markview.presets").headings.simple`, but left-justified
                headings = {
                    ---+ ${conf, Rounded cornered headings}
                    enable = true,
                    shift_width = 0,
                    textoff = 7,
                    heading_1 = make_heading_definition(1),
                    heading_2 = make_heading_definition(2),
                    heading_3 = make_heading_definition(3),
                    heading_4 = make_heading_definition(4),
                    heading_5 = make_heading_definition(5),
                    heading_6 = make_heading_definition(6),
                },
                list_items = {
                    enable = true,
                    wrap = true,

                    indent_size = function(buffer)
                        -- if type(buffer) ~= "number" then
                        --     return vim.bo.shiftwidth or 4
                        -- end

                        --- Use 'shiftwidth' value.
                        return vim.bo[buffer].shiftwidth or 4
                    end,
                    shift_width = 4,

                    marker_minus = {
                        add_padding = false,
                        conceal_on_checkboxes = true,
                        text = "•",
                        hl = "MarkviewListItemMinus",
                    },

                    marker_plus = {
                        add_padding = false,
                        conceal_on_checkboxes = true,

                        text = "+",
                        hl = "MarkviewListItemPlus",
                    },

                    marker_star = {
                        add_padding = false,
                        conceal_on_checkboxes = true,

                        text = "󰫣",
                        hl = "MarkviewListItemStar",
                    },

                    marker_dot = {
                        text = function(_, item)
                            return string.format("%d.", item.n)
                        end,
                        hl = "@markup.list.markdown",
                        add_padding = false,
                        conceal_on_checkboxes = true,
                    },

                    marker_parenthesis = {
                        text = function(_, item)
                            return string.format("%d)", item.n)
                        end,
                        hl = "@markup.list.markdown",
                        add_padding = false,
                        conceal_on_checkboxes = true,
                    },
                },
                horizontal_rules = {
                    enable = true,
                    -- parts = {
                    --     {
                    --         type = "repeating",
                    --         repeat_amount = function()
                    --             return math.ceil(vim.o.columns / 2)
                    --         end,
                    --
                    --         direction = "right",
                    --         text = "━",
                    --         hl = {
                    --             "MarkviewGradient10",
                    --             "MarkviewGradient9",
                    --             "MarkviewGradient8",
                    --             "MarkviewGradient7",
                    --             "MarkviewGradient6",
                    --             "MarkviewGradient5",
                    --             "MarkviewGradient4",
                    --             "MarkviewGradient3",
                    --         },
                    --     },
                    --     {
                    --         type = "repeating",
                    --         repeat_amount = function()
                    --             return math.floor(vim.o.columns / 2)
                    --         end,
                    --
                    --         text = "━",
                    --         hl = {
                    --             "MarkviewGradient10",
                    --             "MarkviewGradient9",
                    --             "MarkviewGradient8",
                    --             "MarkviewGradient7",
                    --             "MarkviewGradient6",
                    --             "MarkviewGradient5",
                    --             "MarkviewGradient4",
                    --             "MarkviewGradient3",
                    --         },
                    --     },
                    -- },
                    parts = {
                        {
                            type = "repeating",
                            repeat_amount = function()
                                return vim.o.columns
                            end,

                            text = "󱑻",
                            hl = {
                                "MarkviewGradient9",
                                "MarkviewGradient8",
                                "MarkviewGradient7",
                                "MarkviewGradient6",
                            },
                        },
                    },
                },
            },
            markdown_inline = {
                checkboxes = {
                    enable = true,
                    -- Every state renders as "• ⟨glyph⟩": the `• ⟨ ⟩` frame is a fixed
                    -- 5 cells, matching the raw "- [x]" width so following text stays
                    -- aligned whether rendered or raw. markview matches custom states
                    -- by the literal character inside the brackets; the glyph + color
                    -- is what distinguishes each one.
                    -- scope_hl = false overrides markview's default (which colors the whole
                    -- task text green/red), so the item text keeps its own formatting.
                    checked = { text = "🯙 󰸞 🯛", scope_hl = false },
                    unchecked = { text = "🭪🯙 🯛🭨", hl = "MarkviewCheckboxUncheckedReverse", scope_hl = false },
                    -- cancelled / dropped — filled badge marker + struck-through task text
                    -- (strike only, no recolor, so other formatting in the item survives)
                    ["-"] = {
                        text = "-----",
                        hl = "MarkviewCheckboxCancelledReverse",
                        scope_hl = "MarkviewCheckboxStrikeOnly",
                    },
                    -- question
                    ["?"] = {
                        text = "🭪¿ ?🭨",
                        hl = "MarkviewCheckboxPendingReverse",
                    },
                    -- answered question (`?` that's now resolved). Multi-char marker —
                    -- enabled by enable_multichar_checkboxes() above. Set via `<localleader>X`.
                    -- Dimmed (blended toward bg) so it recedes vs. the open `[?]`.
                    ["?x"] = { text = "🯙 ?󰸞 🯛", hl = "MarkviewCheckboxPendingDim" },
                    -- in progress / partially done
                    ["/"] = { text = "🯙🭈🭆🭂🭬", hl = "MarkviewCheckboxProgress" },
                    -- rescheduled / forwarded (arrow mirrors the raw `>`)
                    [">"] = { text = "󰁔 ⟩🭨🭬", hl = "MarkviewPalette5Fg" },
                    -- rescheduled, resolved (`>x`) — dimmed
                    [">x"] = { text = "󰁔⟩🯛  󰸞", hl = "MarkviewPalette5FgDim" },
                    -- deferred (arrow mirrors the raw `<`)
                    ["<"] = { text = "🭮🭪⟨ 󰁍", hl = "MarkviewPalette7Fg" },
                    -- deferred, resolved (`<x`) — dimmed
                    ["<x"] = { text = "🯙⟨󰁍  󰸞", hl = "MarkviewPalette7FgDim" },
                    -- important
                    ["!"] = {
                        text = "🭪¡ !🭨",
                        hl = "MarkviewCheckboxImportantReverse",
                    },
                    -- important, resolved (`!x`) — dimmed
                    ["!x"] = { text = "🯙 !󰸞 🯛", hl = "MarkviewCheckboxImportantDim" },
                    -- starred / highlighted
                    ["*"] = {
                        text = "🭪🞱🞱 🭨",
                        hl = "MarkviewCheckboxStarredReverse",
                    },
                    -- starred, resolved (`*x`) — dimmed
                    ["*x"] = { text = "🯙🞯🞯 󰸞🯛", hl = "MarkviewPalette4FgDim" },
                    -- information / note
                    ["i"] = {
                        text = "🭪 ℹ 🭨",
                        hl = "MarkviewCheckboxInfoReverse",
                    },
                    -- information, resolved (`ix`) — dimmed
                    ["ix"] = { text = "🯙 ℹ󰸞 🯛", hl = "MarkviewCheckboxInfoDim" },
                    -- reference / citation
                    ['"'] = {
                        text = "🭪❝ ❞🭨",
                        hl = "MarkviewCheckboxQuoteReverse",
                    },
                    ['"x'] = {
                        text = '🯙 "󰸞 🯛',
                        hl = "MarkviewPalette4FgDim",
                    },
                    -- note (`:`) — neutral marker on the unused Palette4. Rename/restyle freely.
                    [":"] = {
                        text = "🭪: :🭨",
                        hl = "MarkviewCheckboxNoteReverse",
                    },
                    -- note, resolved (`:x`) — dimmed
                    [":x"] = { text = "🯙 :󰸞 🯛", hl = "MarkviewPalette4FgDim" },
                },
                -- Obsidian's parser handles nested tags; Markview only styles the
                -- first segment and conceals `#` while adding padding.
                tags = {
                    enable = false,
                },
            },
        }
        ---@diagnostic enable: missing-fields
        return result
    end,
}
