#!/bin/bash
echo "======================================"
echo "MERKAVA PREDICTION HUD LAUNCHER"
echo "======================================"

cd /home/misi/LGBM_mlops

echo "Cleaning up existing HUD processes..."
pkill -f 'prediction_hud.py' || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "Starting Prediction HUD..."
source venv/bin/activate
python3 HUD_Development/prediction_hud.py > hud_pred.log 2>&1 &
echo "HUD launched in background (PID $!). Check your XRDP desktop."
echo "======================================"
