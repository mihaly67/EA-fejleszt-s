#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT BACKEND V1.99"
echo "======================================"

cd /home/misi/LGBM_mlops

echo "Ensuring previous processes are stopped..."
./stop_lgbm.sh

echo "Starting Micro_LGBM/src/mt5_live_copilot_v1.99_beta.py..."
# Activate the stable venv from the legacy folder
if [ -d "/home/misi/LGBM_mlops/venv" ]; then
    source /home/misi/LGBM_mlops/venv/bin/activate
fi
python3 -u Micro_LGBM/src/mt5_live_copilot_v1.99_beta.py > copilot.log 2>&1 &

echo "Backend V1.99 started in background."
echo "======================================"
