#!/bin/zsh
source "$HOME/.config/sketchybar/plugins/colors.sh"
info=$(pmset -g batt)
pct=$(echo $info | grep -Eo '[0-9]+%' | tr -d %)
[[ -z $pct ]] && { sketchybar --set $NAME drawing=off; exit; }
color=$GREEN
if   [[ $info == *"AC Power"* ]]; then icon=$'\U000F0084'
elif (( pct >= 90 )); then icon=$'\U000F0079'
elif (( pct >= 70 )); then icon=$'\U000F0080'
elif (( pct >= 50 )); then icon=$'\U000F007E'
elif (( pct >= 30 )); then icon=$'\U000F007C'; color=$YELLOW
elif (( pct >= 10 )); then icon=$'\U000F007A'; color=$PEACH
else icon=$'\U000F0083'; color=$RED
fi
sketchybar --set $NAME icon="$icon" icon.color=$(c $color) label="${pct}%"
