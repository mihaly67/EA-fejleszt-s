#!/bin/bash
# Merkava System Watchdog (SAFE MODE)
LOGFILE="/var/log/miner_watchdog.log"
PATTERNS="kryptex|xmrig|xmr\.|47S6DU"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog cycle started." >> $LOGFILE

# 1. Kill strictly known malicious patterns ONLY
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

# 2. Check for rogue systemd fake services specifically in /usr/local/bin
if [ -f "/usr/local/bin/systemd" ]; then
    pkill -9 -f "/usr/local/bin/systemd"
    rm -f /usr/local/bin/systemd
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fake systemd binary deleted." >> $LOGFILE
fi

# CPU blind kill removed completely for system stability.
