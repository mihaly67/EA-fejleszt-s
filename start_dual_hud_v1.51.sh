#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT HUD"
echo "======================================"

cd /home/Jules/LGBM_mlops

echo "Cleaning up existing HUD processes..."
pkill -f 'HUD_Development/dual_hud_v1.51.py' || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "Starting HUD_Development/dual_hud_v1.51.py..."
# Activate the stable venv from the legacy folder (for portability on this VPS without reinstalling)
if [ -d "/home/Jules/LGBM_mlops/venv" ]; then
    source /home/Jules/jules_venv/bin/activate
fi
python3 HUD_Development/dual_hud_v1.51.py > hud.log 2>&1 &

echo "HUD launched in background. Check your XRDP desktop."
echo "======================================"
