# Mérföldkő Dokumentáció (Golden Master) - v2.37 (Deep Stealth Stable)

**Dátum:** 2026.02.18
**Státusz:** STABIL (Termelési Kész)

Ez a dokumentum rögzíti a **Merkava v2.37** és a **Stealth Registry v1.05** konfigurációs állapotát, amely innentől kezdve a rendszer új "Alapbázisa" (Baseline). Minden jövőbeli fejlesztés (v2.38+) ebből a verzióból indul ki.

## 1. Rendszer Komponensek (Verziók)

A rendszer integritása érdekében az alábbi moduloknak kell jelen lenniük:

*   **Fő Program (Expert Advisor):**
    *   `Merkava_v2_37.mq5` (Verzió: 2.37)
    *   *Funkciók:* Deep Stealth integráció, CSV naplózás javítása, Dinamikus verziókijelzés.

*   **Stealth Rendszer (Létfontosságú):**
    *   `StealthRegistry.mqh` (Verzió: 1.05)
        *   *Fix:* Custom PRNG (LCG) a véletlenszám-generáláshoz (megszünteti a "clumping" mintázatot).
        *   *Fix:* Robusztus CSV naplózás (FolderCreate hibakezelés, ékezetmentesítés).
        *   *Seed:* High-Entropy (Microsecond ^ Time ^ Ticks ^ AccountID).
    *   `StealthEngine.mqh` (Verzió: 1.0)
        *   *Funkció:* Emberi viselkedés szimulációja (késleltetés + jitter).

*   **Végrehajtó Modulok:**
    *   `FireControl_v2_22.mqh` (Grid kezelés, Stop/Limit megbízások).
    *   `ProfitManagement_v2_17.mqh` (Virtuális TP/SL, Stealth Zárás).
    *   `NavSystem_v2_20.mqh` (Indikátorok kezelése: Context v3.27, Momentum v2.82, Flow v1.125).
    *   `PanelControl_v2_21.mqh` (Grafikus felület).
    *   `BlackBox_v2_09.mqh` (Telemetria rögzítés).

## 2. Könyvtárszerkezet (Telepítés)

A rendszer automatikusan létrehozza a működéshez szükséges mappákat az első futtatáskor (`OnInit`).

### Forráskód Helye:
*   EA: `MQL5/Indicators/Jules/Merkava_v2_37.mq5`
*   Modulok: `MQL5/Indicators/Indicators/*.mqh`

### Adattárolás (Stealth Adatbázis):
A rendszer **NEM** használja az MT5 beépített History-ját a pozíciók követésére (hogy elrejtse a Magic Number-t). Helyette saját, titkosított(nak tűnő) nyilvántartást vezet:

*   **Gyökérkönyvtár:** `MQL5/Files/Merkava_Stealth/`
*   **Aktív Jegyek (Registry):** `MQL5/Files/Merkava_Stealth/Registry/ActiveTickets.csv`
    *   *Szerepe:* Itt tároljuk, melyik nyitott pozíció tartozik hozzánk. Ha ez a fájl törlődik, a rendszer "elfelejti" a nyitott pozícióit (de a brókernél megmaradnak).
*   **Audit Naplók (Logs):** `MQL5/Files/Merkava_Stealth/Logs/Stealth_Audit_YYYY.MM.DD.csv`
    *   *Szerepe:* Részletes napló minden generált Magic Number-ről és műveletről.
    *   *Formátum:* `Time,Action,Ticket,MagicNumber,Comment` (ANSI kódolás).

## 3. Biztonsági Funkciók (Deep Stealth v1.05)

A v2.37 legnagyobb újítása a bróker oldali profilozás elleni védelem:

1.  **Deep Randomization:**
    *   A szabványos `MathRand()` helyett saját Lineáris Kongruenciális Generátort (LCG) használ.
    *   Cél: Megakadályozni, hogy a bróker algoritmusa statisztikai elemzéssel (pl. Magic Number eloszlás) felismerje a Merkava működését.

2.  **Humanized Magic Numbers:**
    *   Minden kötés új, véletlenszerű azonosítót kap a **10,000 - 999,999** tartományban.
    *   Nincs fix "EA Magic Number" (pl. 123456), ami alapján szűrni lehetne.

3.  **Path Sanitization & Fallback:**
    *   A fájlrendszer-kezelés javítva lett, hogy speciális környezetekben (pl. Wine, VPS) is biztosan írjon naplót.
    *   Ha a `Logs` mappa írása sérül, a rendszer automatikusan a gyökérbe (`MQL5/Files/`) menti a `Merkava_Fallback_Log_*.csv` fájlt.

## 4. Jövőbeli Irányok (Kutatási Dokumentumok)

A `HANDOVER/FINAL_HOTFIX_V2_37/` mappában archivált dokumentumok a következő fázisok alapjait képezik:

*   **MI6 (SIS):** Hálózati forgalomelemzés és "Heartbeat" detektálás (mitmproxy).
*   **Black Ops:** Kliens oldali szuverenitás, memória-injektálás (Frida), kernel szintű álcázás és hardveres input szimuláció (egérmozgás, billentyűzet).

**Jóváhagyta:** Jules (AI Engineer) & Rendszerfőnök
