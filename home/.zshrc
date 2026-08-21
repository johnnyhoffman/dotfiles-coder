# bun on PATH — must precede the sourced config below, whose completion
# guards run `command -v ajent` and need bun-installed tools on PATH.
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ~/.local/bin on PATH. No zsh file added this on Arch — only arch/.bashrc did
# — so claude/codex/opencode/gemini/hive-*/j-* were missing from any shell that
# didn't descend from bash. Ghostty sets `command = "/usr/bin/zsh"`, skipping
# .bashrc entirely, so only zellij sessions whose server predated that change
# still had it. Must precede the sourced config for the same reason as bun.
# mac/.zshenv and coder/overlay/home/.zshenv already add it; `typeset -U path`
# collapses those duplicates (and the doubled bun/rocm entries) to first-wins.
typeset -U path
path=("$HOME/.local/bin" $path)

# Add any customization in source files - this file should be only the source line
source ~/.config/zsh/shared/.zshrc

# bun completions (machine-agnostic — the old hardcoded macOS path was dead on arch)
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
