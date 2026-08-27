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
            # Assuming history_init.csv is generated in a known accessible location.
            # We will look for it in a few places or fallback to empty array.
            csv_paths = [
                "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/history_init.csv",
                os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "history_init.csv"),
                "history_init.csv"
            ]

            loaded = False
            for path in csv_paths:
                if os.path.exists(path):
                    try:
                        with open(path, 'r') as f:
                            reader = csv.reader(f)
                            # skip header if exists. we assume format: time,open,high,low,close
                            # time in mt5 is typically string or unix timestamp. We assume unix timestamp for now, or YYYY.MM.DD HH:MM
                            # Let's handle basic unix timestamp for simplicity, assuming MT5 outputs unix timestamps or we parse it.
                            # MQL5 FileWrite usually outputs string.
                            for row in reader:
                                if len(row) >= 5:
                                    try:
                                        # Assuming first column is unix timestamp in seconds, convert to ms
                                        t_ms = int(row[0]) * 1000
                                        o = float(row[1])
                                        h = float(row[2])
                                        l = float(row[3])
                                        c = float(row[4])
                                        bars.append({
                                            'time': t_ms,
                                            'open': o,
                                            'high': h,
                                            'low': l,
                                            'close': c
                                        })
                                    except ValueError:
                                        pass # Skip header or malformed rows
                        loaded = True
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