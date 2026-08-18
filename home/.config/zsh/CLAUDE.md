# Zsh Config

## Structure

- `shared/.zshrc` — main entrypoint, sources everything below
- `shared/bindkeys.sh` — key bindings (emacs mode, explicit)
- `shared/aliases.sh` — aliases and multi-machine SSH shortcuts
- `shared/etc.sh` — tool integrations and misc setup
- `shared/personal.sh` — personal-machine-only config (j-\* tools, personal ssh hosts); sourced only if present, excluded from the generated work dotfiles (`coder/`)
- `shared/alias-scripts/` — bash scripts for complex alias operations
- `shared/generated/completions/` — auto-generated completions (\_gh, \_zellij); `ajent` is sourced dynamically in `.zshrc` instead
- OS-specific files sourced from `os/bindkeys.sh`, `os/aliases.sh`, `os/etc.sh` (provided by mac/ or arch/ stow packages)

## Conventions

- Shared logic lives here; OS-specific overrides go in `mac/.config/zsh/os/` or `arch/.config/zsh/os/`
- Auto-starts Zellij on shell launch (if not already inside one)
- History: 10,000 items, shared across sessions (inc_append + share_history)

## Tool Integrations

- zoxide, Starship prompt, FZF, ripgrep, mise version manager
- Key aliases: `vim`→nvim, `zj`→zellij, `ls`→eza

## Cross-Config Dependencies

- `EDITOR=nvim` set here
- Zellij auto-start behavior affects terminal session expectations
- Host-specific env vars in `arch/nimo/.zshenv` and `arch/minisforum/.zshenv`
