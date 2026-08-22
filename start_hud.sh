#!/bin/bash
echo "======================================"
echo "🖥️ MERKAVA COPILOT HUD LAUNCHER"
echo "======================================"

if [ -d "/app" ]; then
    cd /app
else
    echo "Warning: /app directory not found."
    exit 1
fi

echo "🧹 Cleaning up existing HUD processes..."
pkill -f 'dual_hud.py' || true
sleep 1

export DISPLAY=:10.0
export QT_QPA_PLATFORM=xcb

echo "🚀 Starting Dual-Pane HUD..."
#source venv/bin/activate
nohup python3 HUD_Development/dual_hud.py > hud.log 2>&1 &
echo "✅ HUD launched in background (PID $!). Check your XRDP desktop."
echo "======================================"
