#!/bin/bash
cd /home/Jules/LGBM_mlops

echo "Meglévő hud_v1.17_nn.py processzek leállítása..."
pkill -f hud_v1.17_nn.py || true

echo "HUD v1.17 (LSTM Meta-Advisor) indítása..."
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb

setsid /home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.17_nn.py > /tmp/hud_v1.17_sh.log 2>&1 &
