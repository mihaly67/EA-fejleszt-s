import paramiko
import os

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    # 1. Kikeressük a legfrissebb CSV fájlt
    stdin, stdout, stderr = ssh.exec_command('''
    ls -t "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/" | grep "Merkava_XAUUSD_MINER_MTF_v1.05" | head -n 1
    ''')
    latest_file = stdout.read().decode().strip()

    if latest_file:
        print(f"Legfrissebb CSV: {latest_file}")

        # 2. Megnézzük a közepéből néhány sort, hogy vannak-e még nullák
        stdin, stdout, stderr = ssh.exec_command(f'''
        tail -n +1000 "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/{latest_file}" | head -n 5 | awk -F',' '{{print "M5 EMA: "$25, " M15 EMA: "$26, " M5 RSI: "$27, " M15 RSI: "$28, " M5 MACD: "$29}}'
        ''')
        print(stdout.read().decode())
    else:
        print("Nincs új CSV fájl.")

    ssh.close()
except Exception as e:
    print(f"Hiba: {e}")
