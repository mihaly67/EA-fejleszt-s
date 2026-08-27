#!/bin/bash
# Note: we use relative paths to make this work anywhere.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "======================================"
echo "STARTING TRADINGVIEW FRONTEND SERVERS"
echo "======================================"

# Display variable set for XRDP
export DISPLAY=:10.0

echo "Killing old instances..."
fuser -k 8000/tcp || true
fuser -k 8765/tcp || true

# Assuming venv is in the same directory or adjust if necessary
if [ -d "venv" ]; then
  source venv/bin/activate
fi

echo "Starting WebSocket Server (Port 8765)..."
python3 HUD_Development/tv_websocket_server.py > ws.log 2>&1 &

echo "Starting HTTP Server (Port 8000)..."
python3 HUD_Development/tv_python_server.py > http.log 2>&1 &

# Wait a second for servers to boot
sleep 2

echo "Launching Browser..."
# Try to launch Chromium or default browser to localhost:8000 on the XRDP display
xdg-open "http://localhost:8000" >/dev/null 2>&1 &
# Fallback if xdg-open fails (Chromium is usually installed on this VPS)
# chromium-browser "http://localhost:8000" >/dev/null 2>&1 &

echo "TV Frontend HTTP and WS Servers started."
echo "Check your browser at http://localhost:8000"
echo "======================================"
