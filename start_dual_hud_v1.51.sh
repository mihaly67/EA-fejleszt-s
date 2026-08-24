#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT HUD"
echo "======================================"

cd /home/misi/LGBM_mlops

echo "Cleaning up existing HUD processes..."
pkill -f "LGBM_mlops.*dual_hud" || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "Starting HUD_Development/dual_hud_v1.51.py..."
# Activate the stable venv from the legacy folder (for portability on this VPS without reinstalling)
if [ -d "/home/misi/LGBM_mlops/venv" ]; then
    source /home/misi/LGBM_mlops/venv/bin/activate
fi
python3 /home/misi/LGBM_mlops/HUD_Development/dual_hud_v1.51.py > hud.log 2>&1 &

echo "HUD launched in background. Check your XRDP desktop."
echo "======================================"
