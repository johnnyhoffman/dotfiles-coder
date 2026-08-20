# Coder workspace environment. The shared zsh config unconditionally sources
# this file; keep it present even when empty.
#
# Zellij auto-attach is ON: the shared .zshrc attaches the "default" session
# at the end of startup, same as the other machines. (Set ZJ_NO_AUTO=1 here
# to opt back out.) Port forwarding is client-side — see `luma-coder-port-forward`
# in the personal dotfiles' contexts/luma package (stowed on m1, where work
# happens), which runs `coder port-forward` loops in a dedicated local
# zellij session.
