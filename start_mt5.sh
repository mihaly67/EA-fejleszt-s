#!/bin/bash
export WINEPREFIX="/home/misi/.wine"
export DISPLAY=:10.0
cd "/home/misi/.wine/drive_c/Program Files/MetaTrader 5 IC Markets EU/"
wine terminal64.exe > /dev/null 2>&1 &
echo "MT5 Started."
