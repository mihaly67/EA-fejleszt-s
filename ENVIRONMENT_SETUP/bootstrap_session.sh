#!/bin/bash
# Ephemeral Devbox Bootstrap (Automata Indító Sablon)
# Ez a script bekéri a TAILSCALE_AUTH_KEY-t és az SSH Privát Kulcsot standard bemenetről,
# vagy környezeti változókból olvassa ki, és felépíti a környezetet a Sandboxban.

echo "==============================================="
echo "  🚀 JULES DEVBOX BOOTSTRAP INICIALIZÁLÁSA  🚀  "
echo "==============================================="

# 1. Tailscale kulcs bekérése
if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    read -p "🔑 Kérlek add meg a TAILSCALE_AUTH_KEY-t: " TAILSCALE_AUTH_KEY
    export TAILSCALE_AUTH_KEY
fi

# 2. SSH Kulcs bekérése (EOF-al lezárt blokk)
SSH_KEY_FILE="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "🔑 Kérlek másold be a teljes SSH Privát Kulcsot! (Ha végeztél, nyomj Enter-t, majd írd be, hogy 'EOF' és üss Enter-t):"
    mkdir -p "$HOME/.ssh"

    # Bekérjük a több soros kulcsot az EOF jelig
    sed -n '/^EOF$/q;p' > "$SSH_KEY_FILE"

    # Jogok beállítása
    chmod 600 "$SSH_KEY_FILE"
    echo "✅ SSH kulcs elmentve: $SSH_KEY_FILE (600)"
else
    echo "✅ SSH kulcs már létezik: $SSH_KEY_FILE"
fi

# 3. Tailscale kapcsolat felépítése Python scripten keresztül
echo "🔗 Tailscale kapcsolat indítása..."
python3 ENVIRONMENT_SETUP/setup_tailscale.py

# 4. Tesztelés
if [ $? -eq 0 ]; then
    echo "📡 Hálózat tesztelése SSH-n keresztül..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 Jules@100.77.191.66 "echo '✅ DEVBOX-HOST KAPCSOLAT SIKERESEN FELÉPÍTVE!'"
    if [ $? -eq 0 ]; then
        echo "==============================================="
        echo " 🎉 BOOTSTRAP SIKERES! A KÖRNYEZET KÉSZ. 🎉  "
        echo "==============================================="

        # Indítjuk a Keep-Alive folyamatot a háttérben, hogy a Devbox ne aludjon el
        if [ -f "ENVIRONMENT_SETUP/keep_alive.sh" ]; then
            ./ENVIRONMENT_SETUP/keep_alive.sh > /tmp/keep_alive.log 2>&1 &
            echo "🛡️ Keep-Alive daemon elindítva (5 percenkénti ping a host felé)."
        fi
    else
         echo "❌ Hiba: Az SSH kapcsolat nem jött létre."
    fi
else
    echo "❌ Hiba a Tailscale csatlakozás közben."
fi
