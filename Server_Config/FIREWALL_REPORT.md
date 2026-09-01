# JULES BOX HÁLÓZATI BIZTONSÁGI JELENTÉS ÉS TŰZFAL TERV

## Jelenlegi Állapot és Architektúra

1. **Szereplők és Portok:**
   - **MT5 EA (Merkava v3.0):** Wine környezetben fut. Adatokat *küld* kifelé (kliensként) az 5555 (Macro) és 5556 (Tick) portokra. A beállított cél: `127.0.0.1`.
   - **Python Copilot:** A `mt5_live_copilot.py` figyel (listen) az 5555 és 5556 portokon. Itt veszi át az EA adatait, feldolgozza, majd **publikálja** a predikciót a ZMQ PUB socketen az 5557 porton.
   - **Python HUD:** Figyeli a Copilot által szórt predikciókat a ZMQ SUB socketen az 5557 porton. (Lehet lokális, vagy lehet távoli, egy Tailscale Devboxon futó kliens).

2. **Kockázat (A "Nyitott Port" probléma):**
   - Ha a Copilot az 5555, 5556 és 5557 portokat `0.0.0.0`-ra bind-olja (ahogy az előző rollback során tettük), akkor ezek a portok *minden* hálózati interfészen kinyílnak.
   - Ez azt jelenti, hogy nem csak a `lo` (127.0.0.1) és a `tailscale0` (100.77.191.66) fér hozzá, hanem az `eth0` (192.168.1.105) fizikai hálózati kártya is. Ha a routered port forwardingja vagy a szolgáltatód miatt ez az interfész kilát az internetre, külső felek is elérhetik/támadhatják az EA portjait.

3. **Miért omlott össze a v2.00, amikor 127.0.0.1-re bindoltuk?**
   A WINE (vagy a Wine alatt futó MT5) hálózati fordítója egyes esetekben nem tudja megfelelően route-olni a lokális socket kapcsolatokat, ha a bind szigorúan `127.0.0.1`-re szól a host gépen. Ahogy a kontextusban korábban volt róla szó, a MT5 a `localhost` hívásokat olykor az operációs rendszer `0.0.0.0` (vagy default route) felé küldi, ami visszapattan, ha a Python szerver szigorúan a loopback-en ül.

## A Megoldás: Hálózati (iptables) Szintű Szeparálás

A Python kódot békén kell hagynunk (`0.0.0.0` bind), hogy az EA a WINE-ból gond nélkül megtalálja a portokat. A védelmet operációs rendszer / tűzfal (iptables) szinten kell megoldani!

**Logika:**
Ahelyett, hogy a kódot korlátoznánk (ami elrontja a WINE-t), a tűzfalon tiltunk le minden bejövő kérést az 5555-5557 portokra, **kivéve**, ha azok biztonságos forrásból jönnek.

**Az `iptables` tűzfal terv:**

1. **Engedélyezés a Loopback-en (Lokális WINE / MT5 forgalom):**
   `sudo iptables -A INPUT -i lo -p tcp -m multiport --dports 5555,5556,5557 -j ACCEPT`
   *(Ez biztosítja, hogy a Jules Boxon futó EA és a Copilot szabadon kommunikálhasson egymással.)*

2. **Engedélyezés a Tailscale-en (Devbox / Távoli HUD forgalom):**
   `sudo iptables -A INPUT -i tailscale0 -p tcp -m multiport --dports 5555,5556,5557 -j ACCEPT`
   *(Ez biztosítja, hogy ha egy HUD egy másik gépen/devboxban fut a VPN hálózatodon, rácsatlakozhasson az 5557-es ZMQ portra).*

3. **Tiltás a nyílt internet / fizikai hálózat felől:**
   `sudo iptables -A INPUT -i eth0 -p tcp -m multiport --dports 5555,5556,5557 -j DROP`
   *(Ez blokkol minden kérést, ami a routered felől (eth0) érkezik ezekre a portokra. Így hiába bindol a Python 0.0.0.0-ra, a port kívülről láthatatlan és zárt marad!)*

**Összegzés:**
Ezzel a beállítással a Copilot és az EA hibátlanul fog kommunikálni, a Devbox HUD-ok elérik a ZMQ streamet, de az otthoni routered / internet felől az 5555, 5556 és 5557-es portok "Stealth" (Eldobva) állapotban lesznek, így a hackerek nem férnek hozzá.
