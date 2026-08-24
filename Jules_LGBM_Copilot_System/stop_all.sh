#!/bin/bash
echo "======================================"
echo "STOPPING JULES LGBM PROCESSES"
echo "======================================"

echo "Killing any running Copilot/HUD instances in this directory..."
# Using pattern match to only kill instances running from Jules_LGBM_Copilot_System
pkill -f "Jules_LGBM_Copilot_System.*mt5_live_copilot" || true
pkill -f "Jules_LGBM_Copilot_System.*dual_hud" || true

echo "All processes stopped successfully."
echo "======================================"
