#!/bin/bash
echo "======================================"
echo "STOPPING ALL LGBM BACKEND PROCESSES"
echo "======================================"

echo "Killing any running mt5_live_copilot instances..."
pkill -f 'mt5_live_copilot' || true

# Free up ports just in case
kill $(lsof -t -i :5555) 2>/dev/null || true
kill $(lsof -t -i :5556) 2>/dev/null || true
kill $(lsof -t -i :5557) 2>/dev/null || true

echo "Backend processes stopped successfully."
echo "======================================"
