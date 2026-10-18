#!/bin/zsh
# install.sh — put these dotfiles in place.
#
#   ./install.sh            link/copy everything (existing files are moved to ~/.dotfiles-backup/<time>/)
#   ./install.sh --dry-run  only print what would happen
#
# Most files are symlinked, so `git pull` updates them. Files that `theme` edits in place
# (btop.conf, zellij config.kdl, zed settings.json, the Spicetify theme) are copied instead.
set -e
cd "${0:A:h}"
REPO=$PWD
DRY=$([[ $1 == --dry-run ]] && echo 1 || echo 0)
BACKUP=$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)

run() { if (( DRY )); then print "  would: $*"; else "$@"; fi }

# move whatever is at $1 out of the way (unless it already points into this repo)
clear_target() {
  local dst=$1
  [[ -L $dst && $(readlink $dst) == $REPO/* ]] && { run rm $dst; return }
  if [[ -e $dst || -L $dst ]]; then
    print "  backup  ${dst/#$HOME/~}"
    (( DRY )) || mkdir -p ${BACKUP}${dst:h}
    run mv $dst ${BACKUP}${dst}
  fi
}

link() { # link <repo path> <target>
  local src=$REPO/$1 dst=$2
  clear_target $dst
  (( DRY )) || mkdir -p ${dst:h}
  print "  link    ${dst/#$HOME/~}"
  run ln -s $src $dst
}

copy() { # copy <repo path> <target>
  local src=$REPO/$1 dst=$2
  clear_target $dst
  (( DRY )) || mkdir -p ${dst:h}
  print "  copy    ${dst/#$HOME/~}"
  run cp -R $src $dst
}

print "→ configs"
for d in aerospace sketchybar borders nvim; do link config/$d $HOME/.config/$d; done
link config/alacritty/alacritty.toml  $HOME/.config/alacritty/alacritty.toml
link config/themes/palettes           $HOME/.config/themes/palettes
link config/themes/make-wallpaper.py  $HOME/.config/themes/make-wallpaper.py
(( DRY )) || mkdir -p $HOME/.config/themes/wallpapers
link config/SHORTCUTS.md              $HOME/.config/SHORTCUTS.md
copy config/btop/btop.conf            $HOME/.config/btop/btop.conf
copy config/zellij/config.kdl         $HOME/.config/zellij/config.kdl
copy config/zed/settings.json         $HOME/.config/zed/settings.json
link config/zed/keymap.json           $HOME/.config/zed/keymap.json
copy config/spicetify/Themes/Rice     $HOME/.config/spicetify/Themes/Rice
link config/spicetify/Extensions/hs-bridge.js $HOME/.config/spicetify/Extensions/hs-bridge.js

print "→ scripts (~/.local/bin)"
for f in bin/*; do link $f $HOME/.local/bin/${f:t}; done

print "→ hammerspoon widgets"
link hammerspoon/init.lua    $HOME/.hammerspoon/init.lua
link hammerspoon/widgets.lua $HOME/.hammerspoon/widgets.lua
link hammerspoon/widgets     $HOME/.hammerspoon/widgets

print "→ karabiner rules"
link karabiner/rice.json $HOME/.config/karabiner/assets/complex_modifications/rice.json

print "→ zsh"
link zsh/.zshrc    $HOME/.zshrc
link zsh/.p10k.zsh $HOME/.p10k.zsh

print "→ firefox"
profile=$(print -l "$HOME/Library/Application Support/Firefox/Profiles/"*.default-release(N/) | head -1)
if [[ -n $profile ]]; then
  link firefox/chrome  "$profile/chrome"
  link firefox/user.js "$profile/user.js"
else
  print "  skipped (no Firefox profile found)"
fi

(( DRY )) && { print "\ndry run: nothing changed"; exit 0 }
[[ -d $BACKUP ]] && print "\nold files saved in ${BACKUP/#$HOME/~}"
cat <<'EOF'

Next steps:
  1. Karabiner-Elements → Complex Modifications → Add predefined rule → enable the "Rice" rules
  2. theme catppuccin-mocha        # generates the per-app colour files (Alacritty, btop, Spicetify…)
  3. brew services start sketchybar && brew services start borders
  4. open AeroSpace and Hammerspoon (give both Accessibility access)
  5. optional extras (Spotify, Discord, Firefox, agenda widget): see README.md
EOF
