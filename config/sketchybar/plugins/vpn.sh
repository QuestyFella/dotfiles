#!/bin/zsh
# WireGuard "PC" tunnel status; click toggles it (see ~/.local/bin/wireguard-toggle).
source "$HOME/.config/sketchybar/plugins/colors.sh"
if /usr/sbin/scutil --nc status PC | head -1 | grep -q '^Connected'; then
  sketchybar --set $NAME icon.color=$(c $GREEN) label.color=$(c $TEXT) label="PC"
else
  sketchybar --set $NAME icon.color=$(c $OVERLAY0) label.color=$(c $OVERLAY0) label="off"
fi
