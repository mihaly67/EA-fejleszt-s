#!/bin/bash
export DISPLAY=:0
export XAUTHORITY=/home/Jules/.Xauthority

PREV_STATUS=""

while true; do
    CURRENT_STATUS=$(xrandr | grep ' connected')

    if [ "$CURRENT_STATUS" != "$PREV_STATUS" ]; then
        xrandr --auto
        PREV_STATUS="$CURRENT_STATUS"
    fi
    sleep 2
done
