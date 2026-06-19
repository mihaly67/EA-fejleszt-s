import paramiko

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    # Elolvassuk a file veget megint
    with open('MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5', 'r', encoding='utf-8') as f:
        content = f.read()

    # Megnezzuk van-e "int m5_shift = iBarShift(" benne (mert ha nem, a reset nem sikerult, az iTime valtozat fut meg)
    if "datetime real_m5_time = iTime" in content:
        print("Igen, meg mindig a hibas 'exact=false' + iTime() logika fut!")

        # JAVITAS: CopyBuffer az iTime() helyett inkabb a shift indexre kerdezzen ra (CopyBuffer MQL5 valtozat indexel: CopyBuffer(handle, buff_num, start_pos, count, buffer_arr))
        # Mert ha time=exact-false volt, es nincs time, akkor iTime() is szemetet (0) adhat ha az iBarShift -1.

        # Uj logika ami biztos mukodik (bar shift-el)
        perfect_m5 = """        int m5_shift = iBarShift(_Symbol, PERIOD_M5, m5_closed_time, false);
        if(m5_shift >= 0) {
            double ema_buffer[1];
            if(CopyBuffer(handle_ema50_m5, 0, m5_shift, 1, ema_buffer) > 0) ema50_m5 = ema_buffer[0];

            double rsi_buffer[1];
            if(CopyBuffer(handle_rsi_m5, 0, m5_shift, 1, rsi_buffer) > 0) rsi_m5 = rsi_buffer[0];

            double macd_buffer[1];
            if(CopyBuffer(handle_macd_m5, 0, m5_shift, 1, macd_buffer) > 0) macd_m5 = macd_buffer[0];
        }"""

        perfect_m15 = """        int m15_shift = iBarShift(_Symbol, PERIOD_M15, m15_closed_time, false);
        if(m15_shift >= 0) {
            double ema_buffer15[1];
            if(CopyBuffer(handle_ema150_m15, 0, m15_shift, 1, ema_buffer15) > 0) ema150_m15 = ema_buffer15[0];

            double rsi_buffer15[1];
            if(CopyBuffer(handle_rsi_m15, 0, m15_shift, 1, rsi_buffer15) > 0) rsi_m15 = rsi_buffer15[0];
        }"""

        old_m5 = """        int m5_shift = iBarShift(_Symbol, PERIOD_M5, m5_closed_time, false);
        datetime real_m5_time = iTime(_Symbol, PERIOD_M5, m5_shift);

        double ema_buffer[1];
        if(CopyBuffer(handle_ema50_m5, 0, real_m5_time, 1, ema_buffer) > 0) ema50_m5 = ema_buffer[0];

        double rsi_buffer[1];
        if(CopyBuffer(handle_rsi_m5, 0, real_m5_time, 1, rsi_buffer) > 0) rsi_m5 = rsi_buffer[0];

        double macd_buffer[1];
        if(CopyBuffer(handle_macd_m5, 0, real_m5_time, 1, macd_buffer) > 0) macd_m5 = macd_buffer[0];"""

        old_m15 = """        int m15_shift = iBarShift(_Symbol, PERIOD_M15, m15_closed_time, false);
        datetime real_m15_time = iTime(_Symbol, PERIOD_M15, m15_shift);

        double ema_buffer15[1];
        if(CopyBuffer(handle_ema150_m15, 0, real_m15_time, 1, ema_buffer15) > 0) ema150_m15 = ema_buffer15[0];

        double rsi_buffer15[1];
        if(CopyBuffer(handle_rsi_m15, 0, real_m15_time, 1, rsi_buffer15) > 0) rsi_m15 = rsi_buffer15[0];"""

        content = content.replace(old_m5, perfect_m5)
        content = content.replace(old_m15, perfect_m15)

        # Save it
        with open('MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5', 'w', encoding='utf-8') as f:
            f.write(content)

        print("Uploading and Compiling...")
        stdin, stdout, stderr = ssh.exec_command("cat > '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5'")
        stdin.write(content)
        stdin.close()

        ssh.exec_command("WINEPREFIX=/home/misi/.mt5 wine '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/metaeditor64.exe' /compile:'/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5' /log")

        import time
        time.sleep(3)
        stdin, stdout, stderr = ssh.exec_command("cat '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.log'")
        print(stdout.read().decode())
    else:
        print("Már visszaállítottuk.")

    ssh.close()
except Exception as e:
    print(f"Hiba: {e}")
