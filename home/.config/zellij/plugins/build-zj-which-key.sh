#!/usr/bin/env zsh
# Build the zj-which-key Zellij plugin (https://github.com/johnae/zj-which-key)
# into this directory. The resulting .wasm is gitignored (portable across
# machines but built per-machine to avoid tracking a binary). Run once per host.
#
# Requires the wasm32-wasip1 Rust target (this script adds it if missing).
# Referenced from config.kdl as file:~/.config/zellij/plugins/zj_which_key.wasm
set -euo pipefail

plugin_dir="${0:A:h}"                       # resolves the symlink to the real repo dir
build_dir="${TMPDIR:-/tmp}/zj-which-key-build"
repo="https://github.com/johnae/zj-which-key"

rustup target add wasm32-wasip1 >/dev/null 2>&1 || true
rm -rf "$build_dir"
git clone --depth 1 "$repo" "$build_dir"
cargo build --release --manifest-path "$build_dir/Cargo.toml" --target wasm32-wasip1
cp "$build_dir/target/wasm32-wasip1/release/zj_which_key.wasm" "$plugin_dir/zj_which_key.wasm"
rm -rf "$build_dir"
echo "Installed zj_which_key.wasm -> $plugin_dir/zj_which_key.wasm"

# Pre-seed plugin permissions so the background auto-show instance runs without
# an interactive prompt (background plugins can't be granted interactively).
# The cache key is the shell-expanded plugin path (no file: prefix), matching
# how Zellij writes the entry itself.
case "$OSTYPE" in
    darwin*) cache_dir="$HOME/Library/Caches/org.Zellij-Contributors.Zellij" ;;
    *)       cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zellij" ;;
esac
perm_file="$cache_dir/permissions.kdl"
mkdir -p "$cache_dir"
# Seed BOTH key forms Zellij may use for this plugin: the bare resolved path
# (used by the layout/keybind-loaded instances) and the `file:`-prefixed form
# (used by the popup the controller spawns via zellij:OWN_URL). Seeding both
# avoids a per-startup re-prompt when the popup's key doesn't match.
for plugin_key in \
    "$HOME/.config/zellij/plugins/zj_which_key.wasm" \
    "file:$HOME/.config/zellij/plugins/zj_which_key.wasm"; do
    if grep -qF "\"$plugin_key\"" "$perm_file" 2>/dev/null; then
        echo "Permissions already present for $plugin_key"
    else
        cat >>"$perm_file" <<EOF
"$plugin_key" {
    ReadApplicationState
    ChangeApplicationState
    MessageAndLaunchOtherPlugins
}
EOF
        echo "Seeded zj-which-key permissions for $plugin_key"
    fi
done
echo "Restart Zellij (kill the server / all sessions) for changes to take effect."
