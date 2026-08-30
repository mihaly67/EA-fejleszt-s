#!/bin/bash
echo "======================================"
echo "STARTING LGBM BACKEND V1.95"
echo "======================================"

cd /home/Jules/LGBM_mlops

echo "Ensuring previous processes are stopped..."
./stop_lgbm.sh

echo "Starting mt5_live_copilot_v1.95_beta.py..."
if [ -d "venv" ]; then
    source ~/jules_venv/bin/activate
fi
python3 Micro_LGBM/src/mt5_live_copilot_v1.95_beta.py > copilot_v1.95.log 2>&1 &

echo "Backend V1.95 started in background."
echo "======================================"
