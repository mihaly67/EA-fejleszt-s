import paramiko
import time

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    with open('MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5', 'r', encoding='utf-8') as f:
        content = f.read()

    # The problem might be the warm up function we added, because CopyBuffer takes Time as parameters.
    # We had:
    # CopyBuffer(handle_ema50_m5, 0, 0, 1, dummy_arr);
    # In MQL5, "start_pos = 0" with "count = 1" means the most recent CURRENT bar. This should be valid!

    # Wait, looking back at fix_mql_zero_bug2.py ...
    # The current M5 logic uses: iBarShift(_Symbol, PERIOD_M5, m5_closed_time, false) -> returns shift index.
    # Then CopyBuffer(handle_ema50_m5, 0, m5_shift, 1, ema_buffer); -> THIS IS CORRECT!

    # So why was it creating an empty / 0-filled array?
    # Because maybe the iMA handles weren't properly initialized? Let's check OnStart:
    # int handle_ema50_m5 = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
    # But wait! I replaced "int handle_ema50_m5 =" with "handle_ema50_m5 =" in a previous step to fix the scope!
    # Let's check if the handles are valid.

    print("MQL5 Script check:")
    print("m5_closed_time logic present?", "m5_closed_time = t -" in content)
    print("iBarShift logic present?", "iBarShift(" in content)
    print("handle_ema50_m5 global present?", "int handle_ema50_m5 = INVALID_HANDLE;" in content)
    print("handle_ema50_m5 init present?", "handle_ema50_m5 = iMA(" in content)

    # What if the script on the VPS is an older version? Let's force upload our perfectly validated local version.
    print("Uploading forced local version to VPS...")
    stdin, stdout, stderr = ssh.exec_command("cat > '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5'")
    stdin.write(content)
    stdin.close()

    ssh.exec_command("WINEPREFIX=/home/misi/.mt5 wine '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/metaeditor64.exe' /compile:'/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5' /log")

    time.sleep(3)
    stdin, stdout, stderr = ssh.exec_command("cat '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.log'")
    print(stdout.read().decode())

    ssh.close()
except Exception as e:
    print(f"Hiba: {e}")
