#!/bin/bash
export WINEPREFIX="/home/misi/.mt5"
export DISPLAY=:10.0
cd "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/"
wine terminal64.exe > /dev/null 2>&1 &
echo "MT5 Started."
