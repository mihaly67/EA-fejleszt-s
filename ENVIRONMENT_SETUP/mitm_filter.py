from mitmproxy import http
import json

# === SANDBOX FILTERING SCRIPT (MI6) ===
# This script is designed for the isolated MX Linux environment.
# It intercepts HTTP/HTTPS traffic and blocks/logs suspicious requests based on MI6 research.

# 1. Telemetry Domains (Blocklist)
BLOCKED_DOMAINS = [
    "crash-reports.metaquotes.net",
    "telemetry.metaquotes.net",
    "analytics.google.com",
    "fingerprintjs.com",
    "amiunique.org",
    "browserleaks.com",
    "whoer.net",
    "ip-api.com",     # Often used for IP geolocation check
    "ipinfo.io"       # Often used for IP geolocation check
]

# 2. Suspicious Headers (Fingerprinting Indicators)
SUSPICIOUS_HEADERS = [
    "X-Fingerprint",
    "X-Client-ID",
    "X-Device-ID"
]

def request(flow: http.HTTPFlow) -> None:
    """Intercepts requests and blocks known telemetry domains."""

    # Check Domain Blocking
    if any(domain in flow.request.pretty_host for domain in BLOCKED_DOMAINS):
        print(f"🚫 BLOCKED: {flow.request.pretty_url}")
        flow.response = http.Response.make(
            403,  # Forbidden
            b"Blocked by MI6 Filter",
            {"Content-Type": "text/plain"}
        )
        return

    # Check for Suspicious Headers (Log Only)
    for header in SUSPICIOUS_HEADERS:
        if header in flow.request.headers:
            print(f"⚠️ SUSPICIOUS HEADER ({header}): {flow.request.headers[header]} in {flow.request.pretty_url}")

def response(flow: http.HTTPFlow) -> None:
    """Inspects responses for tracking scripts."""

    # Basic Content Inspection (e.g., looking for 'fingerprint2.js' in HTML/JS)
    if flow.response.content:
        try:
            content_str = flow.response.content.decode("utf-8", errors="ignore")
            if "fingerprint2" in content_str or "CanvasRenderingContext2D" in content_str:
                print(f"🕵️ DETECTED: Fingerprinting code in {flow.request.pretty_url}")
        except:
            pass
