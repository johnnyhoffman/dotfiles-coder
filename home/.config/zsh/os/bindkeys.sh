# Coder workspace key bindings. The shared zsh config unconditionally sources
# this file; keep it present even when empty.
#
# The workspace is reached from the personal machines' terminals, so it gets
# the union of their escape-sequence bindings: word/line navigation matching
# arch/.config/zsh/os/bindkeys.sh, plus the mac Ghostty Cmd+Backspace (^U) fix.
bindkey "^[[1;3D" backward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;5D" beginning-of-line
bindkey "^[[1;5C" end-of-line
bindkey "^H" kill-line

# Cmd+Backspace in Ghostty (mac) sends ^U: delete only before the cursor,
# not zsh's default kill-whole-line.
bindkey '^U' backward-kill-line
