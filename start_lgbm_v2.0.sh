#!/bin/bash
# start_lgbm_v2.0.sh

echo "================================================="
echo "STARTING JULES LGBM COPILOT BACKEND V2.0 (No Stoch)"
echo "================================================="

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

cd /home/Jules/LGBM_mlops

# Aggressively kill ANY existing python scripts binding to ZMQ Copilot ports (5555, 5556, 5557)
echo "Ensuring previous Copilot processes are stopped..."
pkill -f "mt5_live_copilot" || true
fuser -k 5555/tcp || true
fuser -k 5556/tcp || true
fuser -k 5557/tcp || true

if [ -d "/home/Jules/jules_venv" ]; then
    source /home/Jules/jules_venv/bin/activate
fi

echo "[INFO] Inditom a Live Copilot v2.0 (No Stoch Block) szervert hatterben..."
setsid python3 -u Micro_LGBM/src/mt5_live_copilot_v2.0_no_stoch.py > lgbm_v2.0.log 2>&1 &
echo "[OK] Sikeres inditas."
echo "================================================="
