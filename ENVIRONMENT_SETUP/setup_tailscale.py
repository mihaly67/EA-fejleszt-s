import os
import subprocess
import sys

def setup_tailscale_connection():
    print("🚀 Initializing Tailscale Connection to Jules Dedicated Server...")

    auth_key = os.environ.get("TAILSCALE_AUTH_KEY")
    if not auth_key:
        print("❌ Error: TAILSCALE_AUTH_KEY environment variable is not set. Please set it before running.")
        sys.exit(1)

    # Check if tailscale is installed
    try:
        subprocess.check_output(["tailscale", "version"])
    except FileNotFoundError:
        print("📥 Installing Tailscale...")
        subprocess.run("curl -fsSL https://tailscale.com/install.sh | sh", shell=True)
        subprocess.run(["sudo", "service", "tailscaled", "start"])

    print("🔗 Connecting to VPN...")
    # Attempt to bring interface up
    try:
        subprocess.run(["sudo", "tailscale", "up", "--authkey", auth_key], check=True)
    except Exception as e:
        print(f"⚠️ Warning during tailscale up: {e}")

    # Verify Connection with ping
    print("📡 Pinging 100.77.191.66...")
    result = subprocess.run(["ping", "-c", "3", "100.77.191.66"], capture_output=True, text=True)
    if result.returncode == 0:
        print("✅ Ping successful! Jules Box is online.")
    else:
        print("❌ Ping failed! Jules Box might be offline or Tailscale is not fully active.")

if __name__ == "__main__":
    setup_tailscale_connection()
