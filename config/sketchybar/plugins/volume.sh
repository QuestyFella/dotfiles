#!/bin/zsh
vol=${INFO:-$(osascript -e 'output volume of (get volume settings)')}
if   (( vol >= 60 )); then icon=$'\U000F057E'
elif (( vol >= 30 )); then icon=$'\U000F0580'
elif (( vol > 0 ));   then icon=$'\U000F057F'
else icon=$'\U000F075F'
fi
sketchybar --set $NAME icon="$icon" label="${vol}%"
