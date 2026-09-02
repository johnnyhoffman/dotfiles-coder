#!/usr/bin/env bash
# Coder dotfiles entrypoint (run automatically by `coder dotfiles <repo>`).
# Idempotent — re-run on every workspace build/rebuild.
#
# Everything is best-effort: a missing tool degrades the shell, it never
# breaks the workspace build. Binaries land in ~/.local/bin (no sudo needed);
# apt is used only when passwordless sudo happens to be available.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
export PATH="$LOCAL_BIN:$HOME/.fzf/bin:$PATH"

ARCH="$(uname -m)" # x86_64 | aarch64
FAILED=()

log()  { printf '\033[1;34m[dotfiles]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[dotfiles]\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
fail() { warn "$1 install failed"; FAILED+=("$1"); }

# --- symlink home/ into ~ --------------------------------------------------
# Top-level entries link directly; .config children link individually so the
# workspace's own ~/.config contents survive. Pre-existing real files are
# moved aside once to *.pre-dotfiles.
link_entry() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "moving existing $dst to $dst.pre-dotfiles"
        mv "$dst" "$dst.pre-dotfiles"
    fi
    ln -sfn "$src" "$dst"
}

# nvim rewrites these during normal use (plugin updates, extras/news state).
# They are copied instead of linked so that churn lands in $HOME, the repo
# clone stays pristine, and re-running `coder dotfiles` pulls without
# conflicts. Re-running install.sh resets them to the repo's state.
NVIM_COPY_FILES="lazy-lock.json lazyvim.json"

link_nvim() {
    local src="$1" dst="$HOME/.config/nvim" sub name
    if [ -L "$dst" ]; then rm -f "$dst"; fi # migrate from older wholesale link
    mkdir -p "$dst"
    for sub in "$src"/* "$src"/.[!.]*; do
        [ -e "$sub" ] || continue
        name="$(basename "$sub")"
        case " $NVIM_COPY_FILES " in
            *" $name "*)
                rm -f "$dst/$name"
                cp "$sub" "$dst/$name"
                ;;
            *)
                link_entry "$sub" "$dst/$name"
                ;;
        esac
    done
}

link_home() {
    log "linking dotfiles into ~"
    mkdir -p "$HOME/.cache/zsh" "$LOCAL_BIN"
    local entry sub name
    for entry in "$REPO/home"/.[!.]* "$REPO/home"/*; do
        [ -e "$entry" ] || continue
        name="$(basename "$entry")"
        case "$name" in
            # The workspace's other tools write into ~/.config too — link
            # children, never the dir.
            .config)
                mkdir -p "$HOME/$name"
                for sub in "$entry"/* "$entry"/.[!.]*; do
                    [ -e "$sub" ] || continue
                    if [ "$(basename "$sub")" = "nvim" ]; then
                        link_nvim "$sub"
                    else
                        link_entry "$sub" "$HOME/$name/$(basename "$sub")"
                    fi
                done
                ;;
            *)
                link_entry "$entry" "$HOME/$name"
                ;;
        esac
    done
}

# --- package installs ------------------------------------------------------
APT_READY=""
apt_install() {
    have apt-get || return 1
    sudo -n true 2>/dev/null || return 1
    if [ -z "$APT_READY" ]; then
        sudo apt-get update -qq || true
        APT_READY=1
    fi
    sudo apt-get install -y -qq "$@"
}

# Fetch a version-independent "latest" release asset and untar into a dir.
fetch_tar() { # url dest-dir [tar-args...]
    local url="$1" dest="$2"
    shift 2
    mkdir -p "$dest"
    curl -fsSL --retry 3 --retry-all-errors "$url" | tar -xz -C "$dest" "$@"
}

install_nvim() {
    # LazyVim needs >= 0.10; distro packages are often older, so prefer the
    # official tarball even over an existing old nvim.
    if have nvim && nvim --version | head -1 | grep -qE 'v(0\.[1-9][0-9]|[1-9])'; then
        return
    fi
    log "installing neovim"
    local narch="x86_64"
    [ "$ARCH" = "aarch64" ] && narch="arm64"
    rm -rf "$HOME/.local/opt/nvim-linux-$narch"
    fetch_tar "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$narch.tar.gz" \
        "$HOME/.local/opt" \
        && ln -sfn "$HOME/.local/opt/nvim-linux-$narch/bin/nvim" "$LOCAL_BIN/nvim" \
        || fail nvim
}

install_fzf() {
    # Git-clone install: apt's fzf is too old for `fzf --zsh` (needs >= 0.48).
    have fzf && return
    log "installing fzf"
    { [ -d "$HOME/.fzf" ] || git clone --depth 1 -q https://github.com/junegunn/fzf "$HOME/.fzf"; } \
        && "$HOME/.fzf/install" --bin >/dev/null \
        && ln -sfn "$HOME/.fzf/bin/fzf" "$LOCAL_BIN/fzf" \
        || fail fzf
}

install_rg() {
    have rg && return
    log "installing ripgrep"
    apt_install ripgrep && return
    local url
    url="$(curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/latest \
        | grep -oE "https://[^\"]*${ARCH}-unknown-linux-(musl|gnu)\.tar\.gz" | head -1)"
    [ -n "$url" ] \
        && curl -fsSL --retry 3 --retry-all-errors "$url" | tar -xz --wildcards --strip-components=1 -C "$LOCAL_BIN" '*/rg' \
        || fail ripgrep
}

install_eza() {
    have eza && return
    log "installing eza"
    fetch_tar "https://github.com/eza-community/eza/releases/latest/download/eza_${ARCH}-unknown-linux-gnu.tar.gz" \
        "$LOCAL_BIN" || fail eza
}

install_zellij() {
    have zellij && return
    log "installing zellij"
    fetch_tar "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ARCH}-unknown-linux-musl.tar.gz" \
        "$LOCAL_BIN" || fail zellij
}

install_zoxide() {
    have zoxide && return
    log "installing zoxide"
    apt_install zoxide && return
    curl -sSfL --retry 3 --retry-all-errors https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >/dev/null || fail zoxide
}

install_starship() {
    have starship && return
    log "installing starship"
    fetch_tar "https://github.com/starship/starship/releases/latest/download/starship-${ARCH}-unknown-linux-musl.tar.gz" \
        "$LOCAL_BIN" && return
    curl -sSfL --retry 3 --retry-all-errors https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN" >/dev/null || fail starship
}

install_mise() {
    have mise && return
    log "installing mise"
    curl -fsSL --retry 3 --retry-all-errors https://mise.run | sh >/dev/null || fail mise
}

install_node() {
    # Some nvim tooling (mason-installed LSPs, markdownlint) wants node.
    have node && return
    have mise || return 0
    log "installing node (via mise)"
    mise use -g -q node@lts || fail node
}

install_magick() {
    # ImageMagick scales the PNGs snacks.image places (nvim's mermaid image
    # renders). snacks accepts IM6's `convert` too, so apt's package is fine.
    # Without sudo, the official AppImage (x86_64 only) is extracted — no FUSE
    # needed — and its AppRun stands in for `magick`.
    have magick || have convert && return
    log "installing imagemagick"
    apt_install imagemagick && return
    if [ "$ARCH" != "x86_64" ]; then
        warn "no ImageMagick build for $ARCH without apt; nvim's mermaid image float will not work"
        fail imagemagick
        return
    fi
    local url dest="$HOME/.local/opt/magick"
    url="$(curl -fsSL https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest \
        | grep -oE 'https://[^"]*-gcc-x86_64\.AppImage' | head -1)"
    [ -n "$url" ] \
        && rm -rf "$dest" && mkdir -p "$dest" \
        && curl -fsSL --retry 3 --retry-all-errors -o "$dest/magick.AppImage" "$url" \
        && chmod +x "$dest/magick.AppImage" \
        && (cd "$dest" && ./magick.AppImage --appimage-extract >/dev/null) \
        && rm -f "$dest/magick.AppImage" \
        && ln -sfn "$dest/squashfs-root/AppRun" "$LOCAL_BIN/magick" \
        || fail imagemagick
}

install_mmdr() {
    # Mermaid → PNG for nvim's image renders (config/mermaid.lua): pure Rust,
    # no browser. The release tarball is just the binary.
    have mmdr && return
    log "installing mmdr"
    fetch_tar "https://github.com/1jehuang/mermaid-rs-renderer/releases/latest/download/mmdr-${ARCH}-unknown-linux-gnu.tar.gz" \
        "$LOCAL_BIN" || fail mmdr
}

install_termaid() {
    # Mermaid → Unicode text for nvim's text renders; the `rich` extra is what
    # colours them. Its own venv keeps rich out of the system python.
    have termaid && return
    have python3 || { fail termaid; return; }
    log "installing termaid"
    local venv="$HOME/.local/share/termaid"
    { [ -x "$venv/bin/pip" ] || python3 -m venv "$venv"; } \
        && PIP_DISABLE_PIP_VERSION_CHECK=1 "$venv/bin/pip" install -q 'termaid[rich]' \
        && ln -sfn "$venv/bin/termaid" "$LOCAL_BIN/termaid" \
        || fail termaid
}

run_capped() { # guard against a hung download stalling the workspace build
    if have timeout; then timeout 1500 "$@"; else "$@"; fi
}

install_nvim_plugins() {
    have nvim || return 0
    # mason packages need node/npm; mise-provided node lives behind shims
    [ -d "$HOME/.local/share/mise/shims" ] && export PATH="$HOME/.local/share/mise/shims:$PATH"
    log "installing nvim plugins (Lazy restore, pinned by lazy-lock.json)"
    run_capped nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || fail nvim-plugins
    log "pre-installing mason packages (LSPs, linters, formatters — takes a while)"
    run_capped nvim --headless "+luafile $REPO/nvim-provision.lua" +qa || fail mason-packages
}

install_eslint_deps() {
    # Global TS-style fallback: nvim points config-less projects at
    # ~/.config/eslint, which needs its packages installed once.
    [ -d "$HOME/.config/eslint" ] || return 0
    [ -d "$HOME/.config/eslint/node_modules" ] && return 0
    log "installing global eslint deps"
    if have npm; then
        (cd "$HOME/.config/eslint" && npm ci --silent) || fail eslint-deps
    elif have mise; then
        (cd "$HOME/.config/eslint" && mise x -- npm ci --silent) || fail eslint-deps
    fi
}

# --- git identity ----------------------------------------------------------
ensure_git_identity() {
    # The workspace's admin setup owns the work email, which must stay out of
    # this repo — so no identity dotfile. Fill in whatever is missing in
    # ~/.gitconfig instead (email from the template-provided env), targeting
    # ~/.gitconfig explicitly: ~/.config/git/config is also "global" scope
    # but is a symlink into this repo's clone, and a write landing there
    # would dirty the clone.
    have git || return 0
    if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
        log "setting git user.name"
        git config --file "$HOME/.gitconfig" user.name "Johnny Hoffman"
    fi
    if [ -z "$(git config --global user.email 2>/dev/null)" ] && [ -n "${CODER_USER_EMAIL:-}" ]; then
        log "setting git user.email"
        git config --file "$HOME/.gitconfig" user.email "$CODER_USER_EMAIL"
    fi
}

# --- default shell ---------------------------------------------------------
ensure_zsh() {
    have zsh || apt_install zsh || { fail zsh; return; }
    # chsh authenticates through PAM: the password prompt goes to stderr and
    # the read blocks on the tty, so under 2>/dev/null it is a silent hang
    # until someone hits Enter. Keep it off stdin entirely, and only try the
    # passwordless path — as root, /etc/pam.d/chsh short-circuits on
    # pam_rootok; where sudo is locked down the .bashrc handoff below covers it.
    if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
        sudo -n chsh -s "$(command -v zsh)" "$(id -un)" </dev/null >/dev/null 2>&1 || true
    fi
    local marker="# dotfiles: hand interactive shells to zsh"
    if ! grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
        cat >>"$HOME/.bashrc" <<EOF

$marker
if [ -z "\${ZSH_VERSION:-}" ] && [ -t 1 ] && [ -z "\${NO_ZSH:-}" ] && command -v zsh >/dev/null 2>&1; then
    exec zsh -l
fi
EOF
    fi
    # Coder's SSH sessions start bash as a *login* shell, which reads
    # ~/.bash_profile / ~/.bash_login / ~/.profile — never ~/.bashrc — so the
    # guard above only fires if the profile chain sources .bashrc. Ensure the
    # file bash actually picks (first existing, .bash_profile if none) does.
    local profile
    for profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
        [ -f "$profile" ] && break
    done
    [ -f "$profile" ] || profile="$HOME/.bash_profile"
    if ! grep -q '\.bashrc' "$profile" 2>/dev/null; then
        cat >>"$profile" <<'EOF'

# dotfiles: login shells read .bashrc (where the zsh handoff lives)
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
EOF
    fi
}

# --- main ------------------------------------------------------------------
if ! have curl && ! apt_install curl; then
    warn "curl is unavailable — linking dotfiles only, skipping tool installs"
    link_home
    exit 0
fi

link_home
ensure_git_identity
apt_install build-essential unzip python3 python3-venv >/dev/null 2>&1 || true # treesitter/mason helpers (python3: mason's pip packages, termaid's venv)
ensure_zsh
install_nvim
install_fzf
install_rg
install_eza
install_zellij
install_zoxide
install_starship
install_mise
install_node
install_magick
install_mmdr
install_termaid
install_eslint_deps
install_nvim_plugins

if [ "${#FAILED[@]}" -gt 0 ]; then
    warn "finished with failures: ${FAILED[*]} (shell degrades gracefully; re-run $REPO/install.sh to retry)"
else
    log "done — open a new shell (zsh) and run nvim once to let plugins install"
fi
