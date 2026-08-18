# Neovim Config

## Architecture

- **Lazy.nvim** plugin manager with **LazyVim** distribution ejected locally into `lua/LazyVim-clone/`
- `init.lua` just bootstraps `config.lazy`
- Core config in `lua/config/`: options, keymaps, autocmds; `lua/config/personal.lua` holds personal-machine-only autocmds (j-\* tooling, Obsidian vault stack), loaded via guarded pcall and excluded from the generated work dotfiles (`coder/`)
- `lua/config/lazy.lua` sets up the plugin manager and adds LazyVim-clone to rtp

## Plugin Organization

- `lua/plugins/added/` — custom plugins not part of LazyVim (AI tools, git, markdown/prose, UI)
- `lua/plugins/lazyvim-adjustments/` — overrides/tweaks to LazyVim defaults
- `lua/plugins/root.lua` — top-level plugin specs
- Each file returns a Lua table (or list of tables) with lazy.nvim spec format
- One plugin per file, named after the plugin

## Key Conventions

- **Clone vs adjustments**: Both `lua/LazyVim-clone/` and `lazyvim-adjustments/` are editable. Prefer adjustments when the change is similar effort either way, to minimize diff from upstream LazyVim. Prefer editing the clone when the adjustment approach would add unnecessary complexity or fragile workarounds (e.g., removing features, changing keymaps where the override pattern is more code than the direct edit).
- **Completion**: blink.cmp (not nvim-cmp), with minuet-ai as a custom AI completion source
- **Colorscheme**: Catppuccin Mocha
- **Leader**: Space (LazyVim default)
- **Clipboard**: OSC 52 with a Zellij workaround (Zellij relays copies but not paste responses; nvim caches clipboard reads as fallback)

## Status and Direction

This config is functional but has accumulated polish debt.

- **Linting/formatting**: TS/JS now has a global setup — ESLint (LSP) for linting + formatting via `@stylistic` (chosen over Prettier for TS/JS because it preserves authored layout), Prettier (conform) for JSON/CSS/YAML/HTML/Markdown, plus vtsls tweaks. All defer to project config when present and fall back to global defaults in `~/.config/{prettier,eslint}` otherwise. Precedence so formatters never fight: project eslint config → project Prettier config → global Stylistic. See `lazyvim-adjustments/{conform,eslint,vtsls}.lua` and `.planning/global-ts-style/` for the design + rule choices. ESLint deps live in `~/.config/eslint` (run `npm install` there once per machine). Other languages beyond markdown/TS still not dialed in.
- **Completion (blink.cmp)**: Works well enough, not optimized. Minuet AI completion is set up but underused.

## Cross-Config Dependencies

- Ghostty passes Ctrl+Tab/Shift+Tab through for buffer switching
- Zellij OSC 52 workaround affects clipboard behavior
