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
- `home/.zshrc` — the entire zsh setup, in one file; `home/.zshenv` only sets PATH

## Mermaid

```mermaid fences in markdown render inside nvim: `<localleader>mm` / `mi` draw the diagram as an image (float / inline) through `mermaidx` (the real mermaid.js in an embedded JS engine — no browser), `<localleader>mM` / `mI` as coloured Unicode text through `termaid`. `install.sh` puts both in a venv under `~/.local/share/mermaid-tools`, linked into `~/.local/bin`, and provides ImageMagick for the image path (apt when passwordless sudo exists, otherwise the official AppImage extracted into `~/.local/opt/magick`; x86_64 only), which also needs a kitty-graphics terminal on your side of the SSH session (Ghostty, kitty). Inline images additionally need unicode placeholders, which Zellij doesn't pass yet, so use the float there.

## Zellij

Interactive shells auto-attach the `default` zellij session; set `ZJ_NO_AUTO=1` to opt out.

## GitHub

nvim's octo.nvim (`<leader>gh…`: issue/PR lists and search) drives `gh`. The workspace shell authenticates `gh` with the Coder-provisioned `$GH_TOKEN`, which only carries `repo` + `workflow` (no `read:org`, no `read:project`), and octo's gh subprocess never sees `GH_TOKEN` at all, so it falls through to `~/.config/gh/hosts.yml` (→ `~/.coder-auth/gh-hosts.yml`). Log in there once with a token that has the scopes octo needs:

```sh
env -u GH_TOKEN gh auth login -s read:org
```

Without that login every picker reports "You are not logged into any GitHub hosts" even though `gh` works in the shell. The workspace-only spec `home/.config/nvim/lua/plugins/lazyvim-adjustments/octo.lua` also turns off `default_to_projects_v2` (on in the LazyVim extra), which would otherwise demand `read:project` on octo's first command; add `read:project` to the login and drop that line if you want project fields in PR views.
