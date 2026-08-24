#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT HUD"
echo "======================================"

cd /home/misi/Jules_LGBM_Copilot_System

echo "Cleaning up existing HUD processes..."
pkill -f 'dual_hud_v1.49.py' || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "Starting dual_hud_v1.49.py..."
# Activate the stable venv from the legacy folder (for portability on this VPS without reinstalling)
if [ -d "/home/misi/LGBM_mlops/venv" ]; then
    source /home/misi/LGBM_mlops/venv/bin/activate
fi
python3 dual_hud_v1.49.py > hud.log 2>&1 &

echo "HUD launched in background. Check your XRDP desktop."
echo "======================================"
