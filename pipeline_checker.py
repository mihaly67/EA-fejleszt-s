import socket
import threading
import time

def read_port(port, name):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('', port))
    server.listen(1)
    print(f"[{name}] Listening on port {port}...")
    while True:
        try:
            conn, addr = server.accept()
            print(f"[{name}] EA connected from {addr}")
            # Keep reading
            while True:
                data = conn.recv(4096)
                if not data:
                    print(f"[{name}] EA disconnected.")
                    break
                print(f"[{name}] Received {len(data)} bytes: {data[:60]}...")
        except Exception as e:
            print(f"[{name}] Error: {e}")

if __name__ == '__main__':
    t1 = threading.Thread(target=read_port, args=(5555, 'MACRO (M1)'))
    t2 = threading.Thread(target=read_port, args=(5556, 'MICRO (Tick)'))
    t1.start()
    t2.start()

    while True:
        time.sleep(1)
