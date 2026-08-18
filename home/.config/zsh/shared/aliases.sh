alias vim="nvim"
alias vi="nvim"

alias n='nvim'
alias nvim-lazy='NVIM_APPNAME=nvim-lazy nvim'
alias nvim-kickstart='NVIM_APPNAME=nvim-kickstart nvim'

alias zj='zellij attach --create default options --default-cwd $HOME'

alias claude-bp='claude --permission-mode bypassPermissions'
alias claude-s='claude /sandbox'
alias claude-a='claude --permission-mode auto'

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
