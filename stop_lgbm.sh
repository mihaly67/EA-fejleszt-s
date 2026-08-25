#!/bin/bash
echo "======================================"
echo "STOPPING DEVELOPMENT LGBM BACKEND PROCESSES"
echo "======================================"

echo "Killing any running mt5_live_copilot instances in this directory..."
# Using pattern match to only kill instances running from LGBM_mlops
pkill -f "LGBM_mlops.*mt5_live_copilot" || true

echo "Backend processes stopped successfully."
echo "======================================"
