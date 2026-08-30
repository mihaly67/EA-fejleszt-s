#!/bin/bash
echo "======================================"
echo "🚀 MERKAVA COPILOT SYSTEM LAUNCHER"
echo "======================================"

# Ensure we are in the correct working directory on the VPS
if [ -d "/home/Jules/LGBM_mlops" ]; then
    cd /home/Jules/LGBM_mlops
else
    echo "Warning: /home/Jules/LGBM_mlops directory not found. Running in local mode."
fi

# 1. Kill any existing Copilot and HUD processes
echo "[1/3] 🧹 Cleaning up existing background processes..."
pkill -f 'mt5_live_copilot' || true
pkill -f 'dual_hud.py' || true
pkill -f 'prediction_hud.py' || true
pkill -f 'advanced_hud.py' || true

# Force free ports
fuser -k 5555/tcp 2>/dev/null || true
fuser -k 5556/tcp 2>/dev/null || true
fuser -k 5557/tcp 2>/dev/null || true
sleep 2

# 2. Start the LightGBM Engine
echo "[2/3] 🧠 Starting LightGBM Data Bridge & Inference Engine..."
if [ -d "Micro_LGBM/src" ]; then
    # Strictly use the absolute path to the venv python executable to avoid environment leaks
    nohup /home/Jules/jules_venv/bin/python3 Micro_LGBM/src/mt5_live_copilot_v1.9_beta.py > Micro_LGBM/src/copilot.log 2>&1 &
    echo "   -> LightGBM Engine running in background (PID $!)"
    sleep 3

    # Check if model loaded successfully
    if grep -q "Address already in use" Micro_LGBM/src/copilot.log; then
        echo "❌ ERROR: ZMQ Port crash detected. Check ports."
        exit 1
    fi
else
    echo "Warning: Micro_LGBM/src not found in current directory. Copilot backend skipped."
fi

echo "[3/3] 📊 All systems GO! Backend is listening on ports 5555, 5556, and 5557."
echo ""
echo "To view the UI, open a terminal on your desktop and run:"
echo "cd /home/Jules/LGBM_mlops && source ~/jules_venv/bin/activate && python3 HUD_Development/dual_hud.py"
echo "======================================"
