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

sleep 2

echo "[2/3] Setting up Wine Environment..."
export WINEPREFIX="/home/misi/.wine"
export DISPLAY=:10.0
cd "/home/misi/.wine/drive_c/Program Files/MetaTrader 5 IC Markets EU/"

echo "[3/3] Starting IC Markets MT5 Terminal..."
wine terminal64.exe > /dev/null 2>&1 &

echo "✅ MT5 Started Successfully."
echo "======================================"
