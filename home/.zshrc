# bun on PATH — must precede the sourced config below, whose completion
# guards run `command -v ajent` and need bun-installed tools on PATH.
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Add any customization in source files - this file should be only the source line
source ~/.config/zsh/shared/.zshrc

# bun completions (machine-agnostic — the old hardcoded macOS path was dead on arch)
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
