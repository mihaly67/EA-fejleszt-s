#!/bin/bash
cd /home/Jules/LGBM_mlops

echo "Meglévő hud_v1.05.py processzek leállítása..."
pkill -f hud_v1.05.py

echo "HUD v1.05 (Live Tick) indítása..."
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb

/home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.05.py > /tmp/hud_v1.05_sh.log 2>&1 &
disown
