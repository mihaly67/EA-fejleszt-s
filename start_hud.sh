#!/bin/bash
export QT_QPA_PLATFORM=xcb # Standard X11 display
# Auto-detect the active X11 display (usually :10.0 on xrdp)
ACTIVE_DISPLAY=$(ls /tmp/.X11-unix/ | grep -oP 'X\K\d+' | head -n 1)
export DISPLAY=:${ACTIVE_DISPLAY}.0
export QT_QPA_PLATFORM=xcb

echo "Starting HUD on Display $DISPLAY..."
source /home/misi/LGBM_mlops/venv/bin/activate
cd /home/misi/LGBM_mlops/Micro_LGBM/src
python3 copilot_hud.py > hud.log 2>&1 &
echo "HUD started in background."
