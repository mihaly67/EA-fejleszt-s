#!/bin/bash
export WINEPREFIX="/home/misi/.wine"
export DISPLAY=:10.0
export WINEESYNC=1
export WINEFSYNC=1
export WINEDEBUG=-all

cd "/home/misi/.wine/drive_c/Program Files/MetaTrader 5 IC Markets EU/"

taskset -pc 0-7 $$ >/dev/null 2>&1
wine terminal64.exe > /dev/null 2>&1 &
echo "MT5 Started on all 8 Cores (Fsync Enabled)."
