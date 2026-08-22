#!/bin/bash
echo "======================================"
echo "MERKAVA DUAL HUD V1.4 LAUNCHER"
echo "======================================"

cd /home/misi/LGBM_mlops

echo "Cleaning up existing HUD processes..."
pkill -f 'dual_hud_v1.4.py' || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "Starting Dual-Pane HUD V1.4..."
if [ -d "venv" ]; then
    source venv/bin/activate
fi
python3 HUD_Development/dual_hud_v1.4.py > hud_v1.4.log 2>&1 &
echo "HUD launched in background. Check your XRDP desktop."
echo "======================================"
