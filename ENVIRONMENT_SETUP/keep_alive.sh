#!/bin/bash
# Keep-Alive script a Devbox Tailscale/SSH kapcsolatának fenntartásához

echo "🛡️ Devbox Keep-Alive indítása..."
while true; do
    # Egy apró, erőforrást nem igénylő parancs, amely hálózati forgalmat generál
    # a Devbox és a Jules Box között, megakadályozva az idle (inaktív) állapot miatti lekapcsolást.
    ping -c 1 100.77.191.66 > /dev/null 2>&1
    sleep 300 # 5 percenként egy ping
done
