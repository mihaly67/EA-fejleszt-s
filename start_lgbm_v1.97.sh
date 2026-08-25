#!/bin/bash
echo "======================================"
echo "STARTING JULES LGBM COPILOT BACKEND V1.97"
echo "======================================"

cd /home/misi/LGBM_mlops

echo "Ensuring previous processes are stopped..."
pkill -f 'mt5_live_copilot' || true

# Szabadítsuk fel a portokat
kill $(lsof -t -i :5555) 2>/dev/null || true
kill $(lsof -t -i :5556) 2>/dev/null || true
kill $(lsof -t -i :5557) 2>/dev/null || true
sleep 1

echo "Starting Micro_LGBM/src/mt5_live_copilot_v1.97_beta.py..."
if [ -d "venv" ]; then
    source venv/bin/activate
fi

python3 -u Micro_LGBM/src/mt5_live_copilot_v1.97_beta.py > copilot.log 2>&1 &

echo "Backend V1.97 started in background."
echo "======================================"
