import subprocess
import time
import sys

def check_cpu_vps():
    cmd = "sshpass -p '1104' ssh -o StrictHostKeyChecking=no misi@5.189.163.88 'top -b -n 1 | grep python3 | head -n 5'"
    try:
        output = subprocess.check_output(cmd, shell=True, text=True)
        print("=== VPS PYTHON PROCESSES (TOP) ===")
        print(output.strip())

        # Parse CPU usage
        for line in output.strip().split('\n'):
            parts = line.split()
            if len(parts) >= 9:
                cpu = float(parts[8])
                if cpu > 50.0:
                    print(f"⚠️ FIGYELEM: Magas CPU terhelés! ({cpu}%)")
    except subprocess.CalledProcessError:
        pass

if __name__ == "__main__":
    for _ in range(3):
        check_cpu_vps()
        time.sleep(2)
