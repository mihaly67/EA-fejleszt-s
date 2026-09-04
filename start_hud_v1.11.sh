#!/bin/bash
cd /home/Jules/LGBM_mlops

echo "Meglévő hud_v1.11.py processzek leállítása..."
pkill -f hud_v1.11.py

echo "HUD v1.11 (Live Tick + Prediction Subchart) indítása..."
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb

# Setsid használata a memória direktívának megfelelően, hogy teljesen leváljon a shell-ről
setsid /home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.11.py > /tmp/hud_v1.11_sh.log 2>&1 &
