import asyncio
import json
import websockets
import zmq
import threading
import time

latest_data = {}
running = True

def zmq_listener():
    global latest_data, running
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.connect("tcp://127.0.0.1:5557")
    socket.setsockopt_string(zmq.SUBSCRIBE, "HUD")
    print("[ZMQ] Connected to Copilot on 5557", flush=True)

    while running:
        try:
            msg = socket.recv_string(flags=zmq.NOBLOCK)
            if msg.startswith("HUD "):
                json_data = msg[4:]
                latest_data = json.loads(json_data)
        except zmq.Again:
            time.sleep(0.01)
        except Exception as e:
            print(f"[ZMQ Error] {e}", flush=True)

connected_clients = set()

async def ws_handler(websocket):
    print(f"[WS] New client connected", flush=True)
    connected_clients.add(websocket)
    try:
        last_sent_time = 0
        while True:
            if latest_data and 'timestamp' in latest_data:
                ts = latest_data['timestamp']
                if ts != last_sent_time:
                    payload = json.dumps({
                        "type": "update",
                        "data": latest_data
                    })
                    await websocket.send(payload)
                    last_sent_time = ts
            await asyncio.sleep(0.03)
    except websockets.ConnectionClosed:
        print("[WS] Client disconnected", flush=True)
    except Exception as e:
        print(f"[WS Error] {e}", flush=True)
    finally:
        connected_clients.remove(websocket)

def run_ws_server():
    print("[WS] Starting WebSocket server on port 8765...", flush=True)
    async def serve():
        async with websockets.serve(ws_handler, "127.0.0.1", 8765):
            await asyncio.Future()  # run forever
    asyncio.run(serve())

if __name__ == "__main__":
    t1 = threading.Thread(target=zmq_listener, daemon=True)
    t2 = threading.Thread(target=run_ws_server, daemon=True)

    t1.start()
    t2.start()

    print("Bridge is running. Press Ctrl+C to stop.", flush=True)
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Shutting down...", flush=True)
        running = False