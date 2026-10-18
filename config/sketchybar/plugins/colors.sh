# Shared by sketchybarrc and plugins: load the active theme palette and a colour helper.
source "$HOME/.config/themes/current/palette.sh"
c() { echo "0x${2:-ff}$1"; }   # c <RRGGBB> [alpha] → 0xAARRGGBB
