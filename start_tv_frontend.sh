#!/bin/bash
# Note: we use relative paths to make this work anywhere.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

fuser -k 8000/tcp || true
fuser -k 8765/tcp || true
# Assuming venv is in the same directory or adjust if necessary
if [ -d "venv" ]; then
  source venv/bin/activate
fi
python3 HUD_Development/tv_websocket_server.py > ws.log 2>&1 &
python3 HUD_Development/tv_python_server.py > http.log 2>&1 &
echo "TV Frontend HTTP and WS Servers started."