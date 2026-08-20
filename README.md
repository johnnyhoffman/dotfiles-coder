# dotfiles-coder

Work dotfiles for [Coder](https://coder.com) workspaces: zsh, neovim (LazyVim), zellij, git, prettier.

**Generated repo — do not edit by hand.** This repo is built from a personal dotfiles repo by its `coder/generate.sh`, which filters out personal-only content and re-syncs everything else. Direct edits here are overwritten by the next generation; make changes upstream instead.

## Use

```sh
coder dotfiles <this-repo-url>
```

Coder clones the repo and runs `install.sh`, which symlinks `home/` into `~`, installs missing tools into `~/.local/bin` (apt only when passwordless sudo exists), pre-installs nvim plugins (`Lazy! restore`) and mason packages (`nvim-provision.lua`; LSPs discovered from the config), and hands interactive bash shells to zsh. It is idempotent and safe on rebuilds; set `NO_ZSH=1` to keep a bash shell.

`~/.config/nvim/lazy-lock.json` and `lazyvim.json` are **copied**, not symlinked — nvim rewrites them during normal use, and copies keep the clone pristine so `coder dotfiles` re-runs always pull cleanly. Re-running `install.sh` resets them to the repo's state.

## Layout

- `install.sh` — Coder entrypoint
- `home/` — mirrors `$HOME`; top-level entries and `.config/*` children are symlinked

## Zellij

Interactive shells auto-attach the `default` zellij session (set `ZJ_NO_AUTO=1` to opt out). Port forwarding is client-side: the personal dotfiles ship a `luma-coder-port-forward` wrapper that keeps `coder port-forward` loops alive in a dedicated local zellij session.
