#!/bin/bash
cd /home/Jules/LGBM_mlops

echo "Meglévő hud_v1.15.py processzek leállítása..."
pkill -f hud_v1.15.py

echo "HUD v1.15 indítása..."
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb

setsid /home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.15.py > /tmp/hud_v1.15_sh.log 2>&1 &
