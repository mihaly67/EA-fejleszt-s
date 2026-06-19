import paramiko
import os

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    # Let's list all files to see the latest filename
    stdin, stdout, stderr = ssh.exec_command('''
    ls -lt "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/" | head -n 10
    ''')
    print("Files:\n", stdout.read().decode())

    ssh.close()
except Exception as e:
    print(f"Hiba: {e}")
