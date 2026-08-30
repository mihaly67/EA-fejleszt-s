#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT HUD V1.00"
echo "======================================"

cd /home/Jules/LGBM_mlops

echo "Cleaning up existing HUD processes..."
pkill -f 'hud_v1.00.py' || true
sleep 1

export DISPLAY=:0
export QT_QPA_PLATFORM=xcb

echo "Starting HUD_Development/hud_v1.00.py..."
if [ -d "/home/Jules/jules_venv" ]; then
    source /home/Jules/jules_venv/bin/activate
fi

/home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.00.py > hud.log 2>&1 &

echo "HUD launched in background. Check your desktop."
echo "======================================"
