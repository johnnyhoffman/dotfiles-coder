# Loaded by every zsh before .zshrc: user-local binaries installed by
# install.sh must be on PATH before .zshrc's `command -v` guards run (fzf,
# ripgrep, zoxide, starship, mise, nvim).
export PATH="$HOME/.local/bin:$HOME/.fzf/bin:$PATH"
