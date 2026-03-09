# SESSION HANDOVER: BLACK OPS SNIFFER V5 -> V6 (TRAFFIC ANALYSIS & PLAN B)

**Date:** 2026.03.04 (Estimated)
**Target Next Phase:** Elemzés IN/OUT logok alapján (V6) -> Döntés a blokkolásról vagy áttérés a Frida "Plan B" nyílt szöveg dekódolásra.
**Baseline Version:** `Merkava_v2_40.mq5` (Strict Silence)

## 1. Műveleti Összefoglaló (Executive Summary)
A WINE hálózati architektúrája miatt az eBPF PID-követés (`tcp_sendmsg` + aszinkron `ip_local_out`) elhasalt a "Wine Wall"-on: az MT5 Launcher kilépése, valamint az IPC mechanizmusok miatt a BPF Hash Map logikája csendben eldobta az adatokat.
Stratégiát váltottunk: **A V5 eBPF sniffer immár port-alapú (443)**, teljesen PID-független, és az `ip_local_out` rétegen manuálisan bontja ki a TCP headert a `skb->data`-ból.

## 2. A "Zaj" Probléma és Megoldása
*   A 443-as port sniffingje elöntötte a terminált (2000+ sor/perc) böngésző forgalommal és Kernel szálakkal (`swapper/2`).
*   **Megoldás (V5.1):** Beépítettünk egy `BLACKLIST_COMMS` szűrőt a Python rétegen ("chrome", "vivaldi", "swapper").
*   **Kritikus Megoldás (Kernel szűrés):** A zaj zöme `52 byte`-os, payload nélküli TCP ACK/SYN csomag volt. Ezt a C kódban blokkoltuk (`if (len <= 64) return 0;`), így csak a valós adatok jönnek fel.

## 3. Traffic Analysis - Az MT5 Mintázatok (Eredmény)
A tiszta log fájlokból egyértelmű hálózati mintázatok rajzolódtak ki a titkosítás ellenére:
*   **Telemetria (Besúgó) Burst:** A `controller` (és `MQL5.community`) szál küldi egy specifikus IP-re. Fix méretek: `335 byte`, `126 byte`, `~755-766 byte`.
*   **Kereskedési (EA) Burst:** Az `expert Merkava_` szál küldi. Tipikus méretek: `69 byte` (KeepAlive), `118 byte`, `199 - 212 byte` (Pozíciófelvétel).

## 4. Jelenlegi Állapot: V6 (IN/OUT Sniffer)
A felhasználó kérésére, mielőtt döntenénk a telemetria tűzfalas (eBPF TC) blokkolásáról, látni akarjuk a szerver *válaszait* is.
Elkészült az `ebpf_sniffer_v6_in_out.py`, ami:
1.  Az `ip_local_out` segítségével monitorozza az MT5 kéréseit.
2.  Az `ip_local_deliver` segítségével monitorozza a Bróker válaszait (IN), szűrve a ≤64 byteos zajt.

## 5. Következő Lépések a Jövőbeli Ügynöknek (Next Agent)
1.  **V6 Futattása:** A felhasználó tesztelni fogja a V6 IN/OUT sniffert. Ha a válasz csomagok megvannak, elemezni kell a kapcsolatot (Válaszol-e a bróker a 755 byte-os telemetriára?).
2.  **Stratégiai Döntés:**
    *   *Út A (A Tűzfal):* Ha el akarjuk némítani a telemetriát, írj egy eBPF `Traffic Control (TC)` scriptet, ami DROP-olja a pontosan `335`, `126` és `755` byte méretű csomagokat, hogy az MT5 úgy higgye, nincs net, miközben az EA a 212 byte-os csomagokkal vígan kereskedik.
    *   *Út B (A Frida):* Ha a felhasználó LÁTNI akarja a 755 byte tartalmát, használd a már megírt `frida_sniffer_ws2_32.py`-t. Fontos: ezt WINE alatt futó Windowsos `frida-server.exe`-vel kell bekötni, és a `Secur32.dll` `EncryptMessage` függvényét olvassa nyílt szövegként!

**Jules (Térképszoba Műveleti Tervező)**
