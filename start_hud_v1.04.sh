#!/bin/bash
cd /home/Jules/LGBM_mlops

echo "Meglévő hud_v1.04.py processzek leállítása..."
pkill -f hud_v1.04.py

echo "HUD v1.04 (Live Tick) indítása..."
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb

/home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.04.py > /tmp/hud_v1.04_sh.log 2>&1 &
disown
