import paramiko
import time

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    # I see the problem. The VPS still uses iBarShift(_Symbol, PERIOD_M5, m5_closed_time, false);
    # And it produces 0.0 values.
    # The reason iBarShift returns >=0 but CopyBuffer still fails (or returns 0) is because
    # we are requesting shift FROM THE CURRENT REAL TIME in CopyBuffer, but `m5_shift` is calculated from a point in history!
    # CopyBuffer(handle, 0, shift, 1, buffer) -> `shift` is an offset from the VERY END of the chart (current live market time).
    # If the user is running this on historical data (2025-2026), `m5_shift` will be something like 50,000!
    # CopyBuffer(handle, 0, 50000, 1) -> Tries to get data 50,000 bars ago. This is correct in theory.
    # BUT, the indicators are created with "PRICE_CLOSE". They only calculate up to the available history of the chart.

    # THE BEST WAY TO DO THIS IN MQL5 FOR HISTORY is copying by EXACT TIME!
    # CopyBuffer(handle_ema50_m5, 0, m5_closed_time, 1, ema_buffer); -> This works independently of shift calculations!

    # Let's forcefully apply the time-based copy buffer to the VPS.
    with open('MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5', 'r', encoding='utf-8') as f:
        content = f.read()

    old_m5 = """        datetime m5_open_time = t - (t % 300); // 300 seconds = 5 minutes
        datetime m5_closed_time = m5_open_time - 300;

        int m5_shift = iBarShift(_Symbol, PERIOD_M5, m5_closed_time, false);
        if(m5_shift >= 0) {
            double ema_buffer[1];
            if(CopyBuffer(handle_ema50_m5, 0, m5_shift, 1, ema_buffer) > 0) ema50_m5 = ema_buffer[0];

            double rsi_buffer[1];
            if(CopyBuffer(handle_rsi_m5, 0, m5_shift, 1, rsi_buffer) > 0) rsi_m5 = rsi_buffer[0];

            double macd_buffer[1];
            if(CopyBuffer(handle_macd_m5, 0, m5_shift, 1, macd_buffer) > 0) macd_m5 = macd_buffer[0];
        }"""

    old_m15 = """        // --- Get M15 Closed Data ---
        datetime m15_open_time = t - (t % 900); // 900 seconds = 15 minutes
        datetime m15_closed_time = m15_open_time - 900;

        int m15_shift = iBarShift(_Symbol, PERIOD_M15, m15_closed_time, false);
        if(m15_shift >= 0) {
            double ema_buffer15[1];
            if(CopyBuffer(handle_ema150_m15, 0, m15_shift, 1, ema_buffer15) > 0) ema150_m15 = ema_buffer15[0];

            double rsi_buffer15[1];
            if(CopyBuffer(handle_rsi_m15, 0, m15_shift, 1, rsi_buffer15) > 0) rsi_m15 = rsi_buffer15[0];
        }"""

    new_m5 = """        datetime m5_open_time = t - (t % 300); // 300 seconds = 5 minutes
        datetime m5_closed_time = m5_open_time - 300;

        double ema_buffer[1];
        if(CopyBuffer(handle_ema50_m5, 0, m5_closed_time, 1, ema_buffer) > 0) ema50_m5 = ema_buffer[0];

        double rsi_buffer[1];
        if(CopyBuffer(handle_rsi_m5, 0, m5_closed_time, 1, rsi_buffer) > 0) rsi_m5 = rsi_buffer[0];

        double macd_buffer[1];
        if(CopyBuffer(handle_macd_m5, 0, m5_closed_time, 1, macd_buffer) > 0) macd_m5 = macd_buffer[0];"""

    new_m15 = """        // --- Get M15 Closed Data ---
        datetime m15_open_time = t - (t % 900); // 900 seconds = 15 minutes
        datetime m15_closed_time = m15_open_time - 900;

        double ema_buffer15[1];
        if(CopyBuffer(handle_ema150_m15, 0, m15_closed_time, 1, ema_buffer15) > 0) ema150_m15 = ema_buffer15[0];

        double rsi_buffer15[1];
        if(CopyBuffer(handle_rsi_m15, 0, m15_closed_time, 1, rsi_buffer15) > 0) rsi_m15 = rsi_buffer15[0];"""

    content = content.replace(old_m5, new_m5)
    content = content.replace(old_m15, new_m15)

    with open('MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5', 'w', encoding='utf-8') as f:
        f.write(content)

    print("Uploading to VPS...")
    stdin, stdout, stderr = ssh.exec_command("cat > '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5'")
    stdin.write(content)
    stdin.close()

    print("Compiling on VPS...")
    ssh.exec_command("WINEPREFIX=/home/misi/.mt5 wine '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/metaeditor64.exe' /compile:'/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5' /log")

    time.sleep(3)
    stdin, stdout, stderr = ssh.exec_command("cat '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.log'")
    print(stdout.read().decode())

    ssh.close()
except Exception as e:
    print(f"Hiba: {e}")
