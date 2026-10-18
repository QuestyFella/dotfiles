#!/bin/zsh
# Highlight the focused AeroSpace workspace; show 1–9 always, lettered ones only when in use.
source "$HOME/.config/sketchybar/plugins/colors.sh"
AEROSPACE=/opt/homebrew/bin/aerospace
focused=${FOCUSED_WORKSPACE:-$($AEROSPACE list-workspaces --focused)}
used=(${(f)"$($AEROSPACE list-workspaces --monitor all --empty no)"})
args=()
for sid in $(grep -o "= 'workspace [^ ']*'" ~/.config/aerospace/aerospace.toml | cut -d' ' -f3 | tr -d "'" | awk '!seen[$0]++'); do
  if [[ $sid == $focused ]]; then
    args+=(--set space.$sid drawing=on background.drawing=on background.color=$(c $ACCENT) label.color=$(c $CRUST))
  elif (( ${used[(Ie)$sid]} )); then
    args+=(--set space.$sid drawing=on background.drawing=on background.color=$(c $SURFACE0) label.color=$(c $TEXT))
  elif [[ $sid == <1-9> ]]; then
    args+=(--set space.$sid drawing=on background.drawing=off label.color=$(c $OVERLAY0))
  else
    args+=(--set space.$sid drawing=off)
  fi
done
sketchybar "${args[@]}"
