#!/bin/bash
echo "======================================"
echo "🧹 MT5 & WINE CLEANUP AND RESTART"
echo "======================================"

echo "[1/3] Killing hanging Wine and MT5 processes..."
wineserver -k
pkill -9 -f 'terminal64.exe'
pkill -9 -f 'wineserver'
pkill -9 -f 'winedevice.exe'
pkill -9 -f 'thumbnail.so' || true

# Also kill the fapados enforcer if it exists
pkill -9 -f 'enforce_affinity.sh' || true

sleep 2

echo "[2/3] Setting up Wine Environment..."
export WINEPREFIX="/home/misi/.wine"
export DISPLAY=:10.0
# Force Wine to use esync/fsync for massively better multi-threading and less I/O locking
export WINEESYNC=1
export WINEFSYNC=1
# Disable Wine debug logging completely to avoid massive CPU overhead during startup
export WINEDEBUG=-all

cd "/home/misi/.wine/drive_c/Program Files/MetaTrader 5 IC Markets EU/"

echo "[3/3] Starting IC Markets MT5 Terminal..."
# By wrapping wine with taskset, the terminal and all its child threads natively inherit the 0-7 affinity
taskset -pc 0-7 $$ >/dev/null 2>&1
wine terminal64.exe > /dev/null 2>&1 &

echo "✅ MT5 Started Successfully on all 8 Cores (Fsync Enabled)."
echo "======================================"
