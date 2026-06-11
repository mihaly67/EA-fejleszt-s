#!/bin/bash
# Ez a szkript biztonságosan elindítja a Műszerfalat az asztali ikonról
cd /home/misi/Merkava_ML_Ops
source venv/bin/activate

# Képernyő beállítása, ha az XRDP esetleg elvesztené
export DISPLAY=:10.0 

# Biztonsági törlés hogy ne keveredjen össze a régi hibákkal
rm -f /home/misi/Merkava_ML_Ops/gui_startup.log

# Indítás, logolás a háttérben
python3 vaku3_dashboard_v8.py > /home/misi/Merkava_ML_Ops/gui_startup.log 2>&1
