#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT HUD V1.54"
echo "======================================"

cd /home/misi/LGBM_mlops

echo "Cleaning up existing HUD processes..."
pkill -f 'dual_hud_v1.54.py' || true
pkill -f 'dual_hud' || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "Starting HUD_Development/dual_hud_v1.54.py..."
if [ -d "venv" ]; then
    source venv/bin/activate
fi

python3 HUD_Development/dual_hud_v1.54.py > hud.log 2>&1 &

echo "HUD launched in background. Check your XRDP desktop."
echo "======================================"
