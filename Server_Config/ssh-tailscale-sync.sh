#!/bin/sh
### BEGIN INIT INFO
# Provides:          ssh-tailscale-sync
# Required-Start:    $network $local_fs tailscaled
# Required-Stop:     $network $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Ensures SSH daemon restarts after Tailscale network is fully up.
# Description:       Waits for the tailscale interface (tailscale0) to become active
#                    and assigns an IP before gracefully restarting the SSH service.
### END INIT INFO

LOG_FILE="/var/log/ssh-tailscale-sync.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

case "$1" in
  start)
    log_msg "Starting Tailscale-SSH sync service in the background..."
    # Run the waiting logic in a background subshell so it doesn't block boot
    (
        MAX_RETRIES=30
        RETRY_COUNT=0
        TAILSCALE_UP=0

        log_msg "Waiting for tailscale0 interface to get an IP..."

        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            # Check if tailscale command exists and status is running
            if command -v tailscale >/dev/null 2>&1; then
                # Get tailscale IP if available
                TS_IP=$(tailscale ip -4 2>/dev/null | grep -E '^100\.')
                if [ -n "$TS_IP" ]; then
                    log_msg "Tailscale is up! IP: $TS_IP"
                    TAILSCALE_UP=1
                    break
                fi
            fi

            sleep 2
            RETRY_COUNT=$((RETRY_COUNT+1))
        done

        if [ $TAILSCALE_UP -eq 1 ]; then
            # Give it a few more seconds to settle the routing table and iptables
            sleep 5
            log_msg "Restarting SSH service to bind to the new Tailscale interface..."
            service ssh restart
            if [ $? -eq 0 ]; then
                log_msg "SSH service successfully restarted."
            else
                log_msg "ERROR: Failed to restart SSH service."
            fi
        else
            log_msg "WARNING: Tailscale interface did not come up within 60 seconds. SSH was NOT restarted."
        fi
    ) &
    ;;
  stop)
    log_msg "Stopping Tailscale-SSH sync service (No action required)."
    ;;
  restart|reload|force-reload)
    $0 stop
    $0 start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|reload|force-reload}"
    ;;
esac
