#!/bin/bash
echo "=== MERKAVA COPILOT SYSTEM SHUTDOWN ==="

echo "Terminating LightGBM Backend Engine..."
pkill -f mt5_live_copilot

echo "Terminating Graphical HUD..."
pkill -f copilot_hud

echo "Freeing TCP Ports (5555, 5556, 5557)..."
kill $(lsof -t -i :5555) 2>/dev/null || true
kill $(lsof -t -i :5556) 2>/dev/null || true
kill $(lsof -t -i :5557) 2>/dev/null || true

echo "✅ All Copilot processes successfully stopped."
