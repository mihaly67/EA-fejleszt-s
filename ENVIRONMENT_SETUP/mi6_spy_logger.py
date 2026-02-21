from mitmproxy import http
import json
import base64
import os
import datetime
from urllib.parse import parse_qs, unquote

# === MI6 SPY LOGGER (Advanced MT5 Traffic Analyzer) ===
# This script is a mitmproxy addon.
# It intercepts HTTPS traffic from MT5, decodes payloads, and logs suspicious data points.
# Focus: OrderSend vs. Manual Trade detection, Telemetry, Mouse Tracking.

LOG_FILE = "MI6_SPY_LOG.jsonl"

# Known suspicious keywords in MT5 traffic
SUSPICIOUS_KEYS = [
    "magic", "expert", "id", "uuid", "hardware", "cpu", "gpu", "screen",
    "mouse", "cursor", "click", "focus", "blur",
    "order", "position", "symbol", "volume", "sl", "tp", "comment"
]

class MI6SpyLogger:
    def __init__(self):
        print("🕵️ MI6 Spy Logger Initialized. Intercepting MT5 Traffic...")
        # Ensure log file exists or create header
        if not os.path.exists(LOG_FILE):
            with open(LOG_FILE, 'w', encoding='utf-8') as f:
                pass # Create empty file

    def log_entry(self, entry):
        """Writes a structured log entry to the JSONL file."""
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(json.dumps(entry) + "\n")
        print(f"📝 Logged: {entry['method']} {entry['url']} (Payload: {len(entry.get('request_payload', ''))} chars)")

    def decode_payload(self, content: bytes) -> str:
        """Attempts to decode binary/encoded payloads."""
        if not content:
            return ""

        try:
            # 1. Try UTF-8
            decoded = content.decode('utf-8')
            # Check if it looks like JSON
            if decoded.strip().startswith("{") or decoded.strip().startswith("["):
                try:
                    return json.loads(decoded)
                except:
                    pass
            # Check if it looks like URL-encoded
            if "=" in decoded and "&" in decoded:
                return parse_qs(decoded)
            return decoded
        except:
            pass

        try:
            # 2. Try Base64 (common in telemetry)
            decoded_b64 = base64.b64decode(content).decode('utf-8', errors='ignore')
            if len(decoded_b64) > 5: # Minimal length check
                return f"[BASE64 DECODED] {decoded_b64}"
        except:
            pass

        return f"[BINARY DATA] {len(content)} bytes"

    def analyze_data(self, data):
        """Scans decoded data for suspicious keys."""
        if isinstance(data, dict):
            return {k: v for k, v in data.items() if any(s in k.lower() for s in SUSPICIOUS_KEYS)}
        elif isinstance(data, str):
            # Simple keyword search in string
            found = [s for s in SUSPICIOUS_KEYS if s in data.lower()]
            return found if found else None
        return None

    def request(self, flow: http.HTTPFlow):
        """Intercepts Request."""
        # Only interested in MT5 related traffic (usually metaquotes.net or broker servers)
        # But we log everything for now to be sure.

        payload = self.decode_payload(flow.request.content)
        suspicious_data = self.analyze_data(payload)

        entry = {
            "timestamp": datetime.datetime.now().isoformat(),
            "type": "REQUEST",
            "method": flow.request.method,
            "url": flow.request.pretty_url,
            "headers": dict(flow.request.headers),
            "request_payload": payload,
            "suspicious_keys_found": suspicious_data
        }

        self.log_entry(entry)

    def response(self, flow: http.HTTPFlow):
        """Intercepts Response."""
        # We are also interested in what the server sends back (e.g., confirmation of trade, config updates)

        payload = self.decode_payload(flow.response.content)
        suspicious_data = self.analyze_data(payload)

        entry = {
            "timestamp": datetime.datetime.now().isoformat(),
            "type": "RESPONSE",
            "status_code": flow.response.status_code,
            "url": flow.request.pretty_url,
            "headers": dict(flow.response.headers),
            "response_payload": payload,
            "suspicious_keys_found": suspicious_data
        }

        self.log_entry(entry)

addons = [
    MI6SpyLogger()
]
