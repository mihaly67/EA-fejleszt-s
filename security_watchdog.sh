#!/bin/bash
# Merkava System Watchdog
LOGFILE="/var/log/miner_watchdog.log"
PATTERNS="kryptex|xmrig|xmr\.|47S6DU"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog cycle started." >> $LOGFILE

# 1. Kill known malicious patterns
PIDS=$(pgrep -f "$PATTERNS")
if [ ! -z "$PIDS" ]; then
    for PID in $PIDS; do
        EXE_PATH=$(readlink -f /proc/$PID/exe 2>/dev/null)
        CMD=$(cat /proc/$PID/cmdline 2>/dev/null | tr '\0' ' ')
        kill -9 $PID
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] MALWARE KILLED (PID: $PID) | Cmd: $CMD | Path: $EXE_PATH" >> $LOGFILE

        # Cleanup files in common temp dirs
        if [[ "$EXE_PATH" =~ ^(/tmp|/var/tmp|/dev/shm|/usr/local/bin) ]]; then
            rm -f "$EXE_PATH"
        fi

        # Notify via RDP if active
        MISI_UID=$(id -u misi)
        XAUTH="/home/misi/.Xauthority"
        sudo -u misi DISPLAY=:10 XAUTHORITY="$XAUTH" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$MISI_UID/bus" \
        notify-send -u critical -t 0 "BIZTONSÁGI RIASZTÁS" "Kártevő leállítva: $CMD" 2>/dev/null || true
    done
fi

# 2. Check for rogue systemd fake services
if [ -f "/usr/local/bin/systemd" ]; then
    pkill -9 -f "/usr/local/bin/systemd"
    rm -f /usr/local/bin/systemd
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fake systemd binary deleted." >> $LOGFILE
fi

# 3. Prevent 100% CPU hogs (Kill processes taking >95% CPU that are not allowed like wine/python)
# WARNING: Exclude known heavy processes like wineserver, winedevice.exe, terminal64.exe, python3
HIGH_CPU_PIDS=$(ps -eo pid,pcpu,comm --sort=-pcpu | awk 'NR>1 {if($2>95.0 && $3!="wineserver" && $3!="winedevice.exe" && $3!="terminal64.exe" && $3!="python3") print $1}')
if [ ! -z "$HIGH_CPU_PIDS" ]; then
    for PID in $HIGH_CPU_PIDS; do
        CMD=$(cat /proc/$PID/cmdline 2>/dev/null | tr '\0' ' ')
        kill -9 $PID
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] HIGH CPU PROCESS KILLED (>95%): PID $PID | $CMD" >> $LOGFILE
    done
fi
