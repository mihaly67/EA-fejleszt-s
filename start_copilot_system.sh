#!/bin/bash
echo "=== MERKAVA COPILOT V1.9 BETA STARTUP ==="

# 1. Kill any existing Copilot and HUD processes
echo "[1/3] Terminating existing Copilot and HUD processes..."
pkill -f mt5_live_copilot
pkill -f copilot_hud
kill $(lsof -t -i :5555) 2>/dev/null || true
kill $(lsof -t -i :5556) 2>/dev/null || true
kill $(lsof -t -i :5557) 2>/dev/null || true
sleep 2

# 2. Start the Backend Engine
echo "[2/3] Starting LightGBM Backend Engine..."
cd /home/misi/LGBM_mlops/Micro_LGBM/src
source /home/misi/LGBM_mlops/venv/bin/activate
# Futtatas hatterben
python3 mt5_live_copilot_v1.9_beta.py > copilot_v1_9.log 2>&1 &
sleep 3

# 3. Start the Visual HUD
echo "[3/3] Starting Graphical HUD..."
export QT_QPA_PLATFORM=xcb
ACTIVE_DISPLAY=$(ls /tmp/.X11-unix/ | grep -oP 'X\K\d+' | head -n 1)
if [ -z "$ACTIVE_DISPLAY" ]; then
    echo "Warning: Could not auto-detect active X11 display. Defaulting to :10.0"
    export DISPLAY=:10.0
else
    export DISPLAY=:${ACTIVE_DISPLAY}.0
fi

python3 ../../advanced_hud.py > hud.log 2>&1 &
echo "✅ Copilot System Successfully Launched!"
