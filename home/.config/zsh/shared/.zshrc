# SHARED .ZSHRC #
#
# Should be sourced from ~/.zshrc, and the only thing in that file.
# Sources scri[s directly from ~/.config/zsh/shared, and therefore inderectly from ~/.config/zsh/os.
# Assumes all *os* scripts exist (even if left blank as no-ops).
#
# === == == === #

# Quick terminal: skip all normal setup for speed, run picker, exit.
# GHOSTTY_QUICK_TERMINAL=1 is set by Ghostty >= 1.3.0 in quick terminal surfaces.
if [[ "$GHOSTTY_QUICK_TERMINAL" == "1" ]]; then
    source <(fzf --zsh)
    ~/.config/ghostty/quick-terminal-cmd.sh
    exit 0
fi

source ~/.config/zsh/shared/bindkeys.sh

fpath=($HOME/.config/zsh/shared/generated/completions $fpath)
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

# Extended glob pattern features:
# - Negation
#    - `^`
#    - Matches everything except the following pattern
#    - e.g. `ls ^*.bak` lists all files except those ending in `.bak`
# - Exclusion
#    - `~`
#    - Excludes a specific pattern from a broader match
#    - e.g. `ls *.*~*.bak` lists all files with extensions except `.bak` files
# - Recursive globbing
#    - `**`
#    - Searches through subdirectories recursively
#    - e.g. `ls **/*.txt` lists all `.txt` files in current dir and all subdirs
# - Alternation
#    - `|`
#    - Matches one of multiple patterns (OR operator)
#    - e.g. `ls *.(txt|md)` lists all files ending in `.txt` or `.md`
# - Quantifiers
#    - `?()` zero or one, `+()` one or more, `*()` zero or more
#    - Match patterns with specific occurrence constraints
#    - e.g. `ls ?(*.txt|*.md)` lists files matching zero or one occurrence of the pattern
# - Glob qualifiers
#    - `.` for files, `/` for dirs, `Lm+2` for size, etc.
#    - Filter by metadata rather than name
#    - e.g. `ls *(.)` lists only regular files; `ls *(/)` lists only directories
setopt extended_glob

export EDITOR="nvim"
source ~/.config/zsh/shared/aliases.sh

# Guarded: not all of these exist on every device (Termux installs them via
# pkg, but a fresh phone shouldn't hard-fail the shell).
command -v zoxide &> /dev/null && eval "$(zoxide init zsh)"
command -v starship &> /dev/null && eval "$(starship init zsh)"

if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

command -v fzf &> /dev/null && source <(fzf --zsh)
command -v rg &> /dev/null && source <(rg --generate complete-zsh)

# Personal-only config (j-* tools, personal hosts) — absent on work machines,
# where the generated dotfiles (coder/) exclude the file entirely.
[[ -f ~/.config/zsh/shared/personal.sh ]] && source ~/.config/zsh/shared/personal.sh

# TODO maybe something useful in this stuff (inputrc & prompt)
# set meta-flag on
# set input-meta on
# set output-meta on
# set convert-meta off
# set completion-ignore-case on
# set completion-prefix-display-length 2
# set show-all-if-ambiguous on
# set show-all-if-unmodified on
#
# # Arrow keys match what you've typed so far against your command history
# "\e[A": history-search-backward
# "\e[B": history-search-forward
# "\e[C": forward-char
# "\e[D": backward-char

# # Immediately add a trailing slash when autocompleting symlinks to directories
# set mark-symlinked-directories on

# # Do not autocomplete hidden files unless the pattern explicitly begins with a dot
# set match-hidden-files off

# # Show all autocomplete results at once
# set page-completions off
# TODO I think I want?
set match-hidden-files on
#
# # If there are more than 200 possible completions for a word, ask to show them all
# set completion-query-items 200

# # Show extra file information when completing, like `ls -F` does
# set visible-stats on

# # Be more intelligent when autocompleting by also looking at the text after
# # the cursor. For example, when the current line is "cd ~/src/mozil", and
# # the cursor is on the "z", pressing Tab will not autocomplete it to "cd
# # ~/src/mozillail", but to "cd ~/src/mozilla". (This is supported by the
# # Readline used by Bash 4.)
# set skip-completed-text on

# # Coloring for Bash 4 tab completions.
# set colored-stats on


# source ~/.local/share/omarchy/default/bash/envs
#[[ $- == *i* ]] && bind -f ~/.local/share/omarchy/default/bash/inputrc
# ·. "$HOME/.local/share/../bin/env

# = = = = = =

# Technicolor dreams
# force_color_prompt=yes
# color_prompt=yes

# # Simple prompt with path in the window/pane title and caret for typing line
# PS1=$'\uf0a9 '
# PS1="\[\e]0;\w\a\]$PS1"

# TODO do I need this? (from some other omarchy file, seems related to https://github.com/basecamp/omakub/issues/339)

# # Ensure command hashing is off for mise
# set +h
source ~/.config/zsh/shared/etc.sh

# Auto-start zellij (skipped when HIVE_TUI_NO_ZELLIJ is set — the persistent
# hive-tui Ghostty window sets this so its shells don't contaminate the
# default zellij session; see ~/.config/aerospace/aerospace.toml).
# $TERMUX_VERSION guard: never auto-spawn a multiplexer on the phone.
# $ZJ_NO_AUTO: blanket opt-out — set by environments (e.g. the Coder work
# overlay's os/etc.sh) that want `zj` available but never auto-attached.
if [[ -z "$ZELLIJ" && -z "$ZJ_NO_AUTO" && -z "$HIVE_TUI_NO_ZELLIJ" && -z "$TERMUX_VERSION" ]] && command -v zellij &> /dev/null; then
    # this commented out version is the documented way to do it, which is a simple conditional script that checks to make sure it's not already in a zellij script (the same $ZELLIJ check as above) for $ZELLIJ_AUTO_ATTACH and $ZELLIJ_AUTO_EXIT support
    # eval "$(zellij setup --generate-auto-start zsh)"
    zj
fi
