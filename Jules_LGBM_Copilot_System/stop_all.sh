#!/bin/bash
echo "======================================"
echo "STOPPING ALL JULES LGBM PROCESSES"
echo "======================================"

echo "Killing any running Copilot/HUD instances..."
pkill -f 'mt5_live_copilot.py' || true
pkill -f 'dual_hud.py' || true

# Free up ports just in case
kill $(lsof -t -i :5555) 2>/dev/null || true
kill $(lsof -t -i :5556) 2>/dev/null || true
kill $(lsof -t -i :5557) 2>/dev/null || true

echo "All processes stopped successfully."
echo "======================================"
