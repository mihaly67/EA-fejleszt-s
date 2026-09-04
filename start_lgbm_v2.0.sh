#!/bin/bash
# start_lgbm_v2.0.sh

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

# Kill any existing instances
pkill -f "mt5_live_copilot_v2.0_no_stoch.py" || true

cd /home/Jules/LGBM_mlops

echo "[INFO] Inditom a Live Copilot v2.0 (No Stoch Block) szervert hatterben..."
setsid python3 Micro_LGBM/src/mt5_live_copilot_v2.0_no_stoch.py > lgbm_v2.0.log 2>&1 &
echo "[OK] Sikeres inditas."
