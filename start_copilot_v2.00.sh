#!/bin/bash
#
# JULES CO-PILOT v2.00 INDÍTÓ SCRIPT
echo "=========================================================="
echo "   🚀 INDÍTÁS: MT5 Live Copilot v2.00 "
echo "=========================================================="
cd /home/Jules/LGBM_mlops || exit
echo "🧹 Régi ZMQ portok (5555, 5556, 5557) felszabadítása..."
fuser -k 5555/tcp >/dev/null 2>&1
fuser -k 5556/tcp >/dev/null 2>&1
fuser -k 5557/tcp >/dev/null 2>&1
pkill -f mt5_live_copilot >/dev/null 2>&1
sleep 2
echo "🐍 Python virtuális környezet aktiválása (jules_venv)..."
source /home/Jules/jules_venv/bin/activate
echo "⚙️  Copilot v2.00 indítása..."
nohup python3 -u Micro_LGBM/src/mt5_live_copilot_v2.00.py > /tmp/copilot_v2.log 2>&1 &
sleep 3
if pgrep -f mt5_live_copilot_v2.00.py >/dev/null 2>&1; then
    echo "✅ SIKER: A Copilot v2.00 elindult! (Log: /tmp/copilot_v2.log)"
else
    echo "❌ HIBA: A Copilot nem indult el. Log tartalma:"
    cat /tmp/copilot_v2.log
fi
