#!/bin/bash
echo "=========================================="
echo "STARTING JULES LGBM COPILOT HUD V1.11"
echo "=========================================="

cd /home/Jules/LGBM_mlops

echo "Cleaning up existing HUD processes..."
pkill -f 'hud_v1.11.py' || true
sleep 1

# Kiderítjük, hogy jelenleg melyik display aktív, ha a :0 nem megy
ACTIVE_DISPLAY=$(ls /tmp/.X11-unix/ | grep -oP 'X\K\d+' | head -n 1)
if [ -z "$ACTIVE_DISPLAY" ]; then
    export DISPLAY=:0
else
    export DISPLAY=:${ACTIVE_DISPLAY}.0
fi

echo "[INFO] Használom a DISPLAY=$DISPLAY beállítást..."
export QT_QPA_PLATFORM=xcb

echo "Starting HUD_Development/hud_v1.11.py..."
if [ -d "/home/Jules/jules_venv" ]; then
    source /home/Jules/jules_venv/bin/activate
fi

/home/Jules/jules_venv/bin/python3 HUD_Development/hud_v1.11.py > hud.log 2>&1 &
disown

echo "HUD launched in background. Check your desktop!"
echo "=========================================="
