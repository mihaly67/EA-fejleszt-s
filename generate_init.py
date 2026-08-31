content = """#!/bin/sh
### BEGIN INIT INFO
# Provides:          tailscaled
# Required-Start:    $network $remote_fs $syslog
# Required-Stop:     $network $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Tailscale daemon
# Description:       Tailscale daemon (tailscaled) for secure networking
### END INIT INFO

DAEMON=/usr/sbin/tailscaled
NAME=tailscaled
PIDFILE=/var/run/$NAME.pid

test -x $DAEMON || return 0

. /lib/lsb/init-functions

case "$1" in
  start)
    log_daemon_msg "Starting $NAME"
    start-stop-daemon --start --quiet --background --make-pidfile --pidfile $PIDFILE --exec $DAEMON
    log_end_msg $?
    ;;
  stop)
    log_daemon_msg "Stopping $NAME"
    start-stop-daemon --stop --quiet --pidfile $PIDFILE --retry=TERM/30/KILL/5
    log_end_msg $?
    ;;
  restart|force-reload)
    $0 stop
    sleep 1
    $0 start
    ;;
  status)
    status_of_proc -p $PIDFILE "$DAEMON" "$NAME" && return 0 || return $?
    ;;
  *)
    echo "Usage: /etc/init.d/$NAME {start|stop|restart|force-reload|status}"
    return 1
    ;;
esac
"""
with open("/tmp/tailscaled_init", "w") as f:
    f.write(content)
