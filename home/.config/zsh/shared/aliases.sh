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
alias nvim-lazy='NVIM_APPNAME=nvim-lazy nvim'
alias nvim-kickstart='NVIM_APPNAME=nvim-kickstart nvim'

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

source ~/.config/zsh/os/aliases.sh
