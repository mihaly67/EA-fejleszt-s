#!/bin/bash
# ==============================================================================
# JULES AGENT AUTOMATED BOOTSTRAP SCRIPT (ZÉRÓ BEAVATKOZÁS)
# Ez a script letölti a Tailscale-t, bejelentkezik a környezeti változóban kapott kulccsal,
# és felépíti az SSH hozzáférést a 100.77.191.66-os fizikai géphez.
# ==============================================================================

echo "==============================================="
echo "  🚀 JULES DEVBOX AUTOMATIKUS BOOTSTRAP 🚀  "
echo "==============================================="

TARGET_IP="100.77.191.66"

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    echo "[HIBA] A TAILSCALE_AUTH_KEY környezeti változó nincs beállítva. Kérlek add meg a Reusable kulcsot!"
    # hiba
else

    if [ -z "$SSH_PRIVATE_KEY_B64" ]; then
        echo "[HIBA] A SSH_PRIVATE_KEY_B64 környezeti változó nincs beállítva."
        # hiba
    else

        # 2. Tailscale telepítése és hitelesítése (ha még nincs)
        if ! command -v tailscale &> /dev/null; then
            echo "[INFO] Tailscale letöltése és telepítése..."
            curl -fsSL https://tailscale.com/install.sh > /tmp/ts_install.script && chmod +x /tmp/ts_install.script && sudo /tmp/ts_install.script
            sudo service tailscaled start
        fi

        echo "[INFO] Csatlakozás a Tailscale hálózathoz..."
        sudo tailscale up --authkey "$TAILSCALE_AUTH_KEY"
        sleep 2

        # 3. Hálózati kapcsolat tesztelése
        echo "[INFO] Pingelés ($TARGET_IP)..."
        if ! ping -c 3 "$TARGET_IP" &> /dev/null; then
            echo "[HIBA] A szerver ($TARGET_IP) nem elérhető a Tailscale hálózaton."
        else
            echo "[INFO] Hálózati kapcsolat sikeres."
        fi

        # 4. SSH privát kulcs automatikus létrehozása (környezeti változóból)
        SSH_DIR="$HOME/.ssh"
        KEY_PATH="$SSH_DIR/jules_key"
        mkdir -p "$SSH_DIR"

        echo "$SSH_PRIVATE_KEY_B64" | base64 --decode > "$KEY_PATH"

        chmod 600 "$KEY_PATH"
        echo "[INFO] SSH privát kulcs létrehozva a $KEY_PATH útvonalon."

        # 5. Csatlakozás
        echo " Használd a következő parancsot a belépéshez:"
        echo " ssh -o StrictHostKeyChecking=accept-new -i ~/.ssh/jules_key Jules@100.77.191.66"
    fi
fi
