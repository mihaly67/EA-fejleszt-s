#!/bin/bash
export QT_QPA_PLATFORM=xcb # Standard X11 display
export DISPLAY=:10.0 # Assumed xrdp display
source /home/misi/LGBM_mlops/venv/bin/activate
python3 /home/misi/LGBM_mlops/Micro_LGBM/src/copilot_hud.py
