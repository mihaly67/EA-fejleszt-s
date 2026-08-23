#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT BACKEND"
echo "======================================"

cd /home/misi/Jules_LGBM_Copilot_System

echo "Ensuring previous processes are stopped..."
./stop_all.sh

echo "Starting mt5_live_copilot.py..."
# Activate the stable venv from the legacy folder (for portability on this VPS without reinstalling)
if [ -d "/home/misi/LGBM_mlops/venv" ]; then
    source /home/misi/LGBM_mlops/venv/bin/activate
fi
python3 -u mt5_live_copilot.py > copilot.log 2>&1 &

echo "Backend started in background."
echo "======================================"
