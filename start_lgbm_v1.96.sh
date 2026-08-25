#!/bin/bash
echo "======================================"
echo "STARTING LGBM BACKEND V1.96"
echo "======================================"

cd /home/misi/LGBM_mlops

echo "Ensuring previous processes are stopped..."
if [ -f "./stop_lgbm.sh" ]; then
    ./stop_lgbm.sh
else
    pkill -f 'mt5_live_copilot' || true
fi

echo "Starting mt5_live_copilot_v1.96_beta.py..."
if [ -d "venv" ]; then
    source venv/bin/activate
fi
python3 -u /home/misi/LGBM_mlops/Micro_LGBM/src/mt5_live_copilot_v1.96_beta.py > copilot_v1.96.log 2>&1 &

echo "Backend V1.96 started in background."
echo "======================================"
