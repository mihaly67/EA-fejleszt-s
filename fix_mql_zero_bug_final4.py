import paramiko
import time

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    # Elolvassuk az eredeti filet, hogy lassuk pontosan mi tortent
    with open('MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5', 'r', encoding='utf-8') as f:
        content = f.read()

    # Valtoztassuk meg az iBarShift hívást úgy, hogy egyértelmű legyen.
    # Mivel iBarShift MT5-ben csak a rates_total alapjan mukodik, vagy Custom fgv.-el, de van beépített iBarShift is, ami néha furcsán működik.
    # Egy alternatív megbízhatóbb módszer:
    # A CopyBuffer meghívása önmagában elegendő lenne, HA a dátumot használjuk. Ezt használtuk eredetileg (m5_closed_time).
    # De a "time" overload (datetime start_time, int count, double buffer[]) a 2. overloadja a CopyBuffer-nek.
    # Ahhoz, hogy az MQL5 biztosan az "idő" overloadot használja, és ne az "index" overloadot, a paraméternek datetime típusúnak KELl lennie, ÉS COUNT=1.

    old_m5_logic = """        int m5_shift = iBarShift(_Symbol, PERIOD_M5, m5_closed_time, false);
        if(m5_shift >= 0) {
            double ema_buffer[1];
            if(CopyBuffer(handle_ema50_m5, 0, m5_shift, 1, ema_buffer) > 0) ema50_m5 = ema_buffer[0];

            double rsi_buffer[1];
            if(CopyBuffer(handle_rsi_m5, 0, m5_shift, 1, rsi_buffer) > 0) rsi_m5 = rsi_buffer[0];

            double macd_buffer[1];
            if(CopyBuffer(handle_macd_m5, 0, m5_shift, 1, macd_buffer) > 0) macd_m5 = macd_buffer[0];
        }"""

    new_m5_logic = """        double ema_buffer[1];
        if(CopyBuffer(handle_ema50_m5, 0, m5_closed_time, 1, ema_buffer) > 0) ema50_m5 = ema_buffer[0];

        double rsi_buffer[1];
        if(CopyBuffer(handle_rsi_m5, 0, m5_closed_time, 1, rsi_buffer) > 0) rsi_m5 = rsi_buffer[0];

        double macd_buffer[1];
        if(CopyBuffer(handle_macd_m5, 0, m5_closed_time, 1, macd_buffer) > 0) macd_m5 = macd_buffer[0];"""

    old_m15_logic = """        int m15_shift = iBarShift(_Symbol, PERIOD_M15, m15_closed_time, false);
        if(m15_shift >= 0) {
            double ema_buffer15[1];
            if(CopyBuffer(handle_ema150_m15, 0, m15_shift, 1, ema_buffer15) > 0) ema150_m15 = ema_buffer15[0];

            double rsi_buffer15[1];
            if(CopyBuffer(handle_rsi_m15, 0, m15_shift, 1, rsi_buffer15) > 0) rsi_m15 = rsi_buffer15[0];
        }"""

    new_m15_logic = """        double ema_buffer15[1];
        if(CopyBuffer(handle_ema150_m15, 0, m15_closed_time, 1, ema_buffer15) > 0) ema150_m15 = ema_buffer15[0];

        double rsi_buffer15[1];
        if(CopyBuffer(handle_rsi_m15, 0, m15_closed_time, 1, rsi_buffer15) > 0) rsi_m15 = rsi_buffer15[0];"""

    content = content.replace(old_m5_logic, new_m5_logic)
    content = content.replace(old_m15_logic, new_m15_logic)

    # 2. Add an explicit check inside the loop. If they are 0, try to pull by shift 0 (current) as a fallback just so we see if it's the history missing.
    # No, fallback causes leakage. We MUST use time. But we need to make sure the time is correctly aligned.

    # A probléma: ha egy M5 gyertya mondjuk péntek este 23:55-kor lezár, hétfőn 00:00-ig nincs új adat.
    # A t-(t%300) kiad egy olyan időpontot, amire NINCS gyertya az adatbázisban (pl vasárnap). A CopyBuffer visszadob egy -1-et, és 0.00 marad az érték.
    # EZ volt az iBarShift elõnye (false): megkereste az utolsó létező gyertyát.
    # Hogyan érjük el a CopyBuffer-nél ezt a viselkedést?
    # CopyBuffer egy TÁGTABBAN: CopyBuffer(handle, 0, m5_closed_time, m5_closed_time) -> ez nem jó.

    # MQL5 documentation for iBarShift:
    # int iBarShift(const string symbol, ENUM_TIMEFRAMES timeframe, datetime time, bool exact=false);
    # If exact=false, and time is not found, it returns the index of the NEAREST PRECEDING bar!
    # Wait, earlier when we put `exact=false`, did it return 0.00? Yes, you said the new file has 0.00 everywhere.
    # If iBarShift returns the shift, then CopyBuffer(handle, 0, shift, 1, buffer) should work perfectly.

    # Miért nem működött?
    # Mert az iBarShift egy MQL4 funkció volt. MQL5-ben bevezették, de sokszor hibás a custom symboloknál vagy a history hianyánál.
    # Egy stabil megoldás MQL5-ben: CopyBuffer(handle, 0, m5_closed_time, 1, buffer);
    # CopyBuffer datetime OVERLOAD (start_time, stop_time) VAGY (start_time, count)
    # Ha a start_time (m5_closed_time) OLYAN IDŐPONT, AMIKOR NINCS GYERTYA, akkor a CopyBuffer HIBÁT DOB, mert nincs ott gyertya.

    # A LEGBIZTOSABB MEGOLDÁS (Data Leakage nélküli!):
    # Használjuk az iBarShift-et (exact=false) hogy megkapjuk a létező gyertya idejét, majd ARRA az IDŐRE hivjuk a CopyBuffert!

    perfect_m5 = """        int m5_shift = iBarShift(_Symbol, PERIOD_M5, m5_closed_time, false);
        datetime real_m5_time = iTime(_Symbol, PERIOD_M5, m5_shift);

        double ema_buffer[1];
        if(CopyBuffer(handle_ema50_m5, 0, real_m5_time, 1, ema_buffer) > 0) ema50_m5 = ema_buffer[0];

        double rsi_buffer[1];
        if(CopyBuffer(handle_rsi_m5, 0, real_m5_time, 1, rsi_buffer) > 0) rsi_m5 = rsi_buffer[0];

        double macd_buffer[1];
        if(CopyBuffer(handle_macd_m5, 0, real_m5_time, 1, macd_buffer) > 0) macd_m5 = macd_buffer[0];"""

    perfect_m15 = """        int m15_shift = iBarShift(_Symbol, PERIOD_M15, m15_closed_time, false);
        datetime real_m15_time = iTime(_Symbol, PERIOD_M15, m15_shift);

        double ema_buffer15[1];
        if(CopyBuffer(handle_ema150_m15, 0, real_m15_time, 1, ema_buffer15) > 0) ema150_m15 = ema_buffer15[0];

        double rsi_buffer15[1];
        if(CopyBuffer(handle_rsi_m15, 0, real_m15_time, 1, rsi_buffer15) > 0) rsi_m15 = rsi_buffer15[0];"""

    # We will replace the new logic (which is currently in the file) with this perfect logic.
    content = content.replace(new_m5_logic, perfect_m5)
    content = content.replace(new_m15_logic, perfect_m15)

    # Save it
    with open('MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5', 'w', encoding='utf-8') as f:
        f.write(content)

    print("Uploading and Compiling...")
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
