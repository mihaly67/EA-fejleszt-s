#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT BACKEND V1.96"
echo "======================================"

cd /home/misi/Jules_LGBM_Copilot_System

echo "Ensuring previous processes are stopped..."
./stop_all.sh

echo "Starting mt5_live_copilot_v1.96_beta.py..."
# Activate the stable venv from the legacy folder
if [ -d "/home/misi/LGBM_mlops/venv" ]; then
    source /home/misi/LGBM_mlops/venv/bin/activate
fi
python3 -u mt5_live_copilot_v1.96_beta.py > copilot.log 2>&1 &

echo "Backend V1.96 started in background."
echo "======================================"
