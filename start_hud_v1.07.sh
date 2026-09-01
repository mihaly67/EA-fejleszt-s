#!/bin/bash
cd /home/Jules/LGBM_mlops

echo "Meglévő hud_v1.07.py processzek leállítása..."
pkill -f hud_v1.07.py

echo "HUD v1.07 (Live Tick) indítása..."
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb

/home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.07.py > /tmp/hud_v1.07_sh.log 2>&1 &
disown
