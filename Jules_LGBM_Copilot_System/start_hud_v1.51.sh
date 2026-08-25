#!/bin/bash
echo "======================================"
echo "MERKAVA DUAL HUD V1.51 LAUNCHER"
echo "======================================"

cd /home/misi/Jules_LGBM_Copilot_System

echo "Cleaning up existing HUD processes..."
pkill -f "Jules_LGBM_Copilot_System.*dual_hud" || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "Starting dual_hud_v1.51.py..."
if [ -d "/home/misi/LGBM_mlops/venv" ]; then
    source /home/misi/LGBM_mlops/venv/bin/activate
fi
python3 /home/misi/Jules_LGBM_Copilot_System/dual_hud_v1.51.py > hud.log 2>&1 &
echo "HUD launched in background. Check your XRDP desktop."
echo "======================================"
