#!/bin/bash
# Ez a szkript biztonságosan elindítja a Műszerfalat az asztali ikonról
cd /home/misi/Merkava_ML_Ops
source venv/bin/activate

# Képernyő beállítása, ha az XRDP esetleg elvesztené
export DISPLAY=:10.0 

# Indítás, logolás a háttérben
python3 vaku3_dashboard_10.py > /home/misi/Merkava_ML_Ops/gui_startup.log 2>&1
