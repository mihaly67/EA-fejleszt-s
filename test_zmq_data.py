import zmq
import json
import time

def test_stream():
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.connect("tcp://5.189.163.88:5557") # Connecting via the public IP from the sandbox
    socket.setsockopt_string(zmq.SUBSCRIBE, "")

    print("Listening on tcp://5.189.163.88:5557 for 5 seconds...")
    end_time = time.time() + 5

    while time.time() < end_time:
        try:
            msg = socket.recv_string(flags=zmq.NOBLOCK)
            print("Received raw message:", msg)
        except zmq.Again:
            time.sleep(0.1)

if __name__ == "__main__":
    test_stream()
