import http.server
import socketserver
import os
import json
import csv

class TVHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/history':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()

            bars = []

            csv_paths = [
                "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/history_init.csv"
            ]
            for path in csv_paths:
                if os.path.exists(path):
                    try:
                        with open(path, 'r') as f:
                            reader = csv.reader(f)
                            for row in reader:
                                if len(row) >= 5:
                                    try:
                                        t_ms = int(row[0]) * 1000
                                        bars.append({
                                            'time': t_ms,
                                            'open': float(row[1]),
                                            'high': float(row[2]),
                                            'low': float(row[3]),
                                            'close': float(row[4])
                                        })
                                    except ValueError:
                                        pass
                        # Only return the last 100 bars as requested to keep rendering fast and focused
                        bars = bars[-100:] if len(bars) > 100 else bars
                        print(f"Successfully loaded {len(bars)} historical bars from MT5 CSV.")
                        break
                    except Exception as e:
                        print(f"Error reading CSV {path}: {e}")

            self.wfile.write(json.dumps(bars).encode())
            return

        return super().do_GET()

def run_http_server():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tv_frontend'))
    PORT = 8000
    with socketserver.TCPServer(("127.0.0.1", PORT), TVHandler) as httpd:
        print("HTTP Server serving at port", PORT, flush=True)
        httpd.serve_forever()

if __name__ == '__main__':
    run_http_server()