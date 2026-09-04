#!/bin/bash
# start_nn_advisor.sh

echo "================================================="
echo "STARTING NN META-ADVISOR"
echo "================================================="

cd /home/Jules/LGBM_mlops

pkill -f "nn_meta_advisor.py" || true

if [ -d "/home/Jules/jules_venv" ]; then
    source /home/Jules/jules_venv/bin/activate
fi

echo "[INFO] Inditom a NN Meta-Advisor szervert hatterben..."
setsid python3 -u Micro_LGBM/src/nn_meta_advisor.py > nn_advisor.log 2>&1 &
echo "[OK] Sikeres inditas."
echo "================================================="
