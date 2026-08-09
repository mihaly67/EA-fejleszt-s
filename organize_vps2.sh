#!/bin/bash

BASE="/home/misi/LGBM_mlops"
MICRO="$BASE/Micro_LGBM/src"
MACRO="$BASE/Macro_Regime/src"
LIVE="$BASE/Live_Trading/src"
SHARED="$BASE/Shared_Utils"

# Clean up previously failed moves (if they got trapped in Micro_LGBM/src due to how `find` listed them initially)
# It seems some files are actually inside Micro_LGBM/src right now, based on the `ls -la $MICRO` output above.

# Move Macro files from wherever they are to MACRO
mv "$MACRO/kaufman_ama.py" "$SHARED/" 2>/dev/null
mv "$MICRO/kaufman_ama.py" "$SHARED/" 2>/dev/null

# From Micro to Live Trading
mv "$MICRO/mt5_live_copilot.py" "$LIVE/" 2>/dev/null
mv "$MICRO/copilot_hud.py" "$LIVE/" 2>/dev/null
mv "$MICRO/start_hud.sh" "$LIVE/" 2>/dev/null

# Move pipeline master to root if it was in Micro
mv "$MICRO/pipeline_master.py" "$BASE/" 2>/dev/null

echo "Second pass organization complete. Checking structures:"
echo "--- MICRO ---"
ls -la "$MICRO"
echo "--- MACRO ---"
ls -la "$MACRO"
echo "--- LIVE TRADING ---"
ls -la "$LIVE"
echo "--- SHARED UTILS ---"
ls -la "$SHARED"
