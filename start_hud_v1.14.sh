#!/bin/bash
cd /home/Jules/LGBM_mlops

echo "Meglévő hud_v1.14.py processzek leállítása..."
pkill -f hud_v1.14.py

echo "HUD v1.14 indítása..."
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb

setsid /home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.14.py > /tmp/hud_v1.14_sh.log 2>&1 &
