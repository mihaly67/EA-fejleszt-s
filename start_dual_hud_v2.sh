#!/bin/bash
echo "======================================"
echo "MERKAVA DUAL HUD V2 LAUNCHER"
echo "======================================"

cd /home/misi/LGBM_mlops

echo "Cleaning up existing HUD processes..."
pkill -f 'dual_hud_v2.py' || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "Starting Dual-Pane HUD V2..."
source venv/bin/activate
python3 HUD_Development/dual_hud_v2.py > hud_v2.log 2>&1 &
echo "HUD launched in background (PID $!). Check your XRDP desktop."
echo "======================================"
