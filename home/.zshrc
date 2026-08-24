# Zsh config for Coder workspaces — the whole interactive shell setup, in one
# file. Generated: edits here are overwritten by the next sync (see README).
#
# ~/.zshenv is the only other zsh file: it puts ~/.local/bin on PATH for every
# zsh, including the non-interactive ones that never read this file.

bindkey -e

# Escape sequences sent by the terminals used to reach the workspace.
bindkey "^[[1;3D" backward-word     # Alt+Left
bindkey "^[[1;3C" forward-word      # Alt+Right
bindkey "^[[1;5D" beginning-of-line # Ctrl+Left
bindkey "^[[1;5C" end-of-line       # Ctrl+Right
bindkey "^H" kill-line

# Cmd+Backspace arrives as ^U in some terminals: delete only what is before the
# cursor, not zsh's default kill-whole-line.
bindkey '^U' backward-kill-line

fpath=($HOME/.config/zsh/completions $fpath)
autoload -Uz compinit
mkdir -p ~/.cache/zsh
compinit -d ~/.cache/zsh/zcompdump

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt append_history
setopt extended_history
setopt inc_append_history
setopt share_history

setopt extended_glob

export EDITOR="nvim"

# Follow Neovim's cwd on exit: nvim writes its final global cwd to $NVIM_CWD_FILE
# (VimLeavePre autocmd in nvim/lua/config/autocmds.lua) and we cd there. Lets
# neogit's worktree popup (`w` in the status buffer) move the shell too, since a
# child process can't chdir its parent. Only interactive shells resolve this
# function — $EDITOR and anything exec'ing nvim still get the plain binary.
nvim() {
    local cwd_file dest ret
    cwd_file=$(mktemp "${TMPDIR:-/tmp}/nvim-cwd.XXXXXX") || {
        command nvim "$@"
        return $?
    }
    NVIM_CWD_FILE=$cwd_file command nvim "$@"
    ret=$?
    [[ -s $cwd_file ]] && dest=$(<"$cwd_file")
    rm -f "$cwd_file"
    [[ -n $dest && -d $dest && $dest != $PWD ]] && cd -- "$dest"
    return $ret
}

alias vim="nvim"
alias vi="nvim"

alias n='nvim'

alias zj='zellij attach --create default options --default-cwd $HOME'

alias ca='claude agents'
alias cu='claude /usage'

# Run Prettier / ESLint with my global config from the CLI (Neovim does this
# automatically; Prettier/ESLint never auto-load a global config themselves).
# These force the global config regardless of the project — use them on
# config-less projects; projects with their own config should use plain prettier/eslint.
alias prettier-global='prettier --config ~/.config/prettier/config.json'
alias eslint-global='~/.config/eslint/node_modules/.bin/eslint --config ~/.config/eslint/eslint.config.mjs'

alias real-ls='\ls'
alias ls='eza'
alias ls2='eza --tree --level 2'
alias ls3='eza --tree --level 3'
alias ls4='eza --tree --level 4'
alias ls5='eza --tree --level 5'
alias ls6='eza --tree --level 6'

command -v zoxide &> /dev/null && eval "$(zoxide init zsh)"
command -v starship &> /dev/null && eval "$(starship init zsh)"

if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

command -v fzf &> /dev/null && source <(fzf --zsh)
command -v rg &> /dev/null && source <(rg --generate complete-zsh)

# Auto-attach the "default" zellij session. ZJ_NO_AUTO=1 opts out; the `-t 0`
# test keeps headless `zsh -ic` invocations (build hooks, CI) from spawning a
# multiplexer.
if [[ -t 0 && -z "$ZELLIJ" && -z "$ZJ_NO_AUTO" ]] && command -v zellij &> /dev/null; then
    zj
fi
