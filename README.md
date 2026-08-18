# dotfiles-coder

Work dotfiles for [Coder](https://coder.com) workspaces: zsh, neovim (LazyVim), zellij, git, prettier.

**Generated repo — do not edit by hand.** This repo is built from a personal dotfiles repo by its `coder/generate.sh`, which filters out personal-only content and re-syncs everything else. Direct edits here are overwritten by the next generation; make changes upstream instead.

## Use

```sh
coder dotfiles <this-repo-url>
```

Coder clones the repo and runs `install.sh`, which symlinks `home/` into `~`, installs missing tools into `~/.local/bin` (apt only when passwordless sudo exists), and hands interactive bash shells to zsh. It is idempotent and safe on rebuilds; set `NO_ZSH=1` to keep a bash shell.

## Layout

- `install.sh` — Coder entrypoint
- `home/` — mirrors `$HOME`; top-level entries and `.config/*` children are symlinked
