# 🕵️ MI6 INTERCEPTION GUIDE: MT5 Traffic Analysis (Man-in-the-Middle)

**Dátum:** 2026.02.21
**Cél:** Az MT5 titkosított (HTTPS) forgalmának feltörése és elemzése WINE környezetben.
**Eszköz:** `mitmproxy` + `mi6_spy_logger.py`

Ez az útmutató lépésről lépésre bemutatja, hogyan állítsd be a rendszert, hogy "beláss" az MT5 és a bróker szerverei közé.

## ⚠️ FIGYELEM
Ez a művelet **bizalmas adatokhoz** (jelszavak, session tokenek) férhet hozzá. Csak **DEMO számlán** használd kísérletezésre!

---

## 1. Előkészületek (A Proxy Indítása)

Először el kell indítanunk a `mitmproxy`-t a `mi6_spy_logger.py` addonnal. Ez fogja elkapni és naplózni az adatokat.

1.  Nyiss egy terminált az MX Linuxon (vagy a Sandboxban).
2.  Lépj a projekt gyökerébe.
3.  Futtasd a következő parancsot:

```bash
mitmweb -s ENVIRONMENT_SETUP/mi6_spy_logger.py --listen-port 8080 --web-port 8081
```

*   `mitmweb`: Grafikus felületet is indít (a böngésződben: `http://127.0.0.1:8081`), ahol élőben látod a forgalmat.
*   `-s ...`: Betölti a mi kém szkriptünket.
*   `--listen-port 8080`: Ezen a porton figyel a proxy.

Hagyd futni ezt a terminált!

---

## 2. A "Hamis" Tanúsítvány Telepítése (WINE)

Ahhoz, hogy az MT5 ne vegye észre a lehallgatást (és ne dobjon SSL hibát), telepítenünk kell a `mitmproxy` CA tanúsítványát a WINE "Trusted Root Certification Authorities" tárolójába.

1.  **Tanúsítvány letöltése:**
    *   Ha fut a proxy, nyisd meg a böngészőben a `mitm.it` címet.
    *   Kattints a "Linux" vagy "Other" gombra a `mitmproxy-ca-cert.pem` letöltéséhez.
    *   (Alternatíva: A fájl általában itt is megtalálható: `~/.mitmproxy/mitmproxy-ca-cert.pem`).

2.  **Konvertálás (CRT formátumba):**
    A Windows/WINE `.crt` formátumot szeret.
    ```bash
    cp ~/.mitmproxy/mitmproxy-ca-cert.pem ~/.mitmproxy/mitmproxy-ca-cert.crt
    ```

3.  **Telepítés a WINE-ba:**
    Futtasd ezt a parancsot a terminálban (ahol az MT5 WINE prefixe van):
    ```bash
    # Ha az alapértelmezett WINE prefixet használod:
    wine control
    # Ha egyedi prefixet (pl. ~/.wine_mi6):
    WINEPREFIX=~/.wine_mi6 wine control
    ```

4.  **A Vezérlőpultban:**
    *   Kattints az "Internet Settings" (Internetbeállítások) ikonra.
    *   Menj a "Content" (Tartalom) fülre.
    *   Kattints a "Certificates" (Tanúsítványok) gombra.
    *   Válaszd a "Trusted Root Certification Authorities" (Megbízható legfelsőbb hitelesítésszolgáltatók) fület.
    *   Kattints az "Import..." gombra.
    *   Tallózd be a `mitmproxy-ca-cert.crt` fájlt.
    *   Kövesd a varázslót ("Yes", "Ok").

---

## 3. Az MT5 Proxy Beállítása

Most meg kell mondanunk az MT5-nek (vagy az egész WINE környezetnek), hogy használja a proxyt.

**A) WINE Szintű Beállítás (Ajánlott):**
Indítsd az MT5-öt így:

```bash
export http_proxy=http://127.0.0.1:8080
export https_proxy=http://127.0.0.1:8080
WINEPREFIX=~/.wine_mi6 wine "C:\\Program Files\\MetaTrader 5\\terminal64.exe" /portable
```

**B) MT5 Belső Beállítás:**
1.  Indítsd el az MT5-öt.
2.  Eszközök (Tools) -> Beállítások (Options) -> Közösség (Community) fül (vagy Hálózat, verziótól függ).
3.  Pipáld be az "Engedélyezze a Proxy szervert" (Enable proxy server).
4.  Kattints a "Proxy..." gombra.
5.  Szerver: `127.0.0.1`, Port: `8080`, Típus: `HTTP` (vagy SOCKS5, ha a mitmproxy úgy fut).
6.  Teszteld a kapcsolatot.

---

## 4. A Kísérlet (Black Ops)

1.  Győződj meg róla, hogy a `mitmweb` fut.
2.  Indítsd el az MT5-öt a fenti beállításokkal.
3.  **Figyeld a Logs fájlt:** `MI6_SPY_LOG.jsonl` a projekt gyökerében.
4.  **Cselekedj:**
    *   Nyiss egy pozíciót KÉZZEL.
    *   Nyiss egy pozíciót EA-val (Magic Number beállítva).
    *   Mozgasd az egeret a charton.
    *   Válts idősíkot.
5.  **Elemzés:**
    *   Nézd meg a logban a `request_payload` mezőket.
    *   Keress különbséget a "kézi" és "EA" kötések között (JSON payloadban `expert_id`, `magic`, `comment`).
    *   Keress `telemetry` vagy `analytics` kéréseket egérmozgáskor.

**Sok sikert, Ügynök!** 🕵️
