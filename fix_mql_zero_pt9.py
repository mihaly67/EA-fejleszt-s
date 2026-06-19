import paramiko
import time

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    stdin, stdout, stderr = ssh.exec_command('''
    cat "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5" | grep -A 20 "datetime m5_closed_time"
    ''')
    print("VPS Loop Content:")
    print(stdout.read().decode())

    ssh.close()
except Exception as e:
    print(f"Hiba: {e}")
