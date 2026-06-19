import paramiko
import os

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    # Let's check the tail of this new file
    stdin, stdout, stderr = ssh.exec_command('''
    tail -n 20 "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/Merkava_XAUUSD_MINER_MTF_v105_20260619_184336.csv" | awk -F',' '{print "M5 EMA: "$25, " M15 EMA: "$26, " M5 RSI: "$27, " M15 RSI: "$28, " M5 MACD: "$29}'
    ''')
    print("Values:\n", stdout.read().decode())

    ssh.close()
except Exception as e:
    print(f"Hiba: {e}")
