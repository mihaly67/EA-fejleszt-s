import paramiko
import time

VPS_IP = '5.189.163.88'
VPS_USER = 'misi'
VPS_PASS = '1104'

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=10)

    # Elolvassuk a VPS-en levo MQ5 fajlt hogy lassuk, ott mi a helyzet. Mivel az elozoleg a repoba betoltott fura lehet.
    stdin, stdout, stderr = ssh.exec_command("cat '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Scripts/Merkava_Data_Miner_Script_v1_05_MTF.mq5'")
    content = stdout.read().decode()

    # Megnezzuk a CopyBuffer parameterit. A dokumentacio szerint:
    # CopyBuffer(handle, buffer_num, start_time, count, buffer_array) -> ez kéri a kezdo es vegpontot (vagy count) idoben.
    # UGYANAKKOR, az idonek pontosan egyeznie kell egy nyitott gyertyaval az adott idosikon (M5, M15).
    # A legbiztosabb modja a "jovobelatas mentes" lekerdezesnek az index alapu, ha a megfeleloen konvertalt indexet (shiftet) hasznaljuk.

    # Valamiert az iBarShift(.., false) a V1.05-ben nem talalta az indexet (lehet hogy custom symbol, off-market hours).
    # Hasznalhatjuk a masik Time overloadot, de elobb olvassuk ki a pontos Time[i]-t a history-bol!

    # Az MQL5-ben van egy dedikalt fugveny egy masik timefreamebol adatolvasasra Series-bol, ha rates_total helyett iClose(_Symbol, PERIOD_M5, shift) hivast hasznalunk.
    # Ez a legregebbi es legstabilabb MQL4/5 módszer, ráadásul indikátorok is lekerdezhetők iMAArray stb, de a CopyBuffer is jó.

    # Modositsuk az MTF blokkot:
    # A time-ot rates[i].time adja, amibol kiszamoltuk a lezart m5 es m15 idot.

    mtf_logic = """
        // --- Get M5 Closed Data ---
        datetime m5_closed_time = t - (t % 300) - 300;
        double ema_buffer[1];
        if(CopyBuffer(handle_ema50_m5, 0, m5_closed_time, 1, ema_buffer) > 0) ema50_m5 = ema_buffer[0];

        double rsi_buffer[1];
        if(CopyBuffer(handle_rsi_m5, 0, m5_closed_time, 1, rsi_buffer) > 0) rsi_m5 = rsi_buffer[0];

        double macd_buffer[1];
        if(CopyBuffer(handle_macd_m5, 0, m5_closed_time, 1, macd_buffer) > 0) macd_m5 = macd_buffer[0];

        // --- Get M15 Closed Data ---
        datetime m15_closed_time = t - (t % 900) - 900;

        double ema_buffer15[1];
        if(CopyBuffer(handle_ema150_m15, 0, m15_closed_time, 1, ema_buffer15) > 0) ema150_m15 = ema_buffer15[0];

        double rsi_buffer15[1];
        if(CopyBuffer(handle_rsi_m15, 0, m15_closed_time, 1, rsi_buffer15) > 0) rsi_m15 = rsi_buffer15[0];
"""

    if mtf_logic in content:
        print("Igen, ez a szoros time alapu CopyBuffer van a VPS-en (t - t%300 - 300).")
    else:
        print("Valamiert mas van a VPS-en a loopban!")

    ssh.close()
except Exception as e:
    print(f"Hiba: {e}")
