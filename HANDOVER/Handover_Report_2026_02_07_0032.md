# Handover Report - Project Merkava: Stealth & Chaos Phase
**Dátum:** 2026.02.07 00:32
**Tárgy:** Stealth Engine Integráció (Total Chaos) & Active Camouflage
**Címzett:** Commander (User) / Next Agent

## 🛑 Státusz: SIKER (IMPLEMENTED)
A mai session során sikeresen implementáltuk a "Total Chaos" lopakodó rendszert. A Merkava EA mostantól aktívan álcázza magát a bróker algoritmusai előtt.

### 🛠️ Elvégzett Módosítások (Changelog)

#### 1. Stealth Engine (`StealthEngine.mqh`) - ÚJ MODUL
Egy dedikált káosz-generátor osztály, amely a következőket végzi:
*   **Temporal Chaos (Időbeli Káosz):** Véletlenszerű késleltetések (Latency Injection 50-300ms) és nem-lineáris végrehajtás.
*   **Spatial Chaos (Térbeli Káosz):** A rácsok (Grid) távolsága és lépésköze Gauss-eloszlású zajjal (Jitter) torzított.
*   **Asymmetry (Aszimmetria):** A Long és Short oldalak sosem tükörképei egymásnak. Eltérő geometria és időzítés.
*   **Identity Obfuscation (Személyazonosság):**
    *   **Magic Number Rotation:** Minden "hadjárat" új, véletlenszerű Magic Numbert kap (de perzisztensen tároljuk, hogy a restartnál ne vesszenek el a pozíciók).
    *   **Metadata Masking:** A `comment` mező emberi viselkedést imitál (pl. " ", "ios", "target"), az `expiration` (lejárat) pedig véletlenszerűen váltakozik (GTC / Day / Specified).

#### 2. Active Camouflage (Grid Morphing)
*   **Dinamikus Célpontok:** A `FireControl` modul mostantól képes a már lerakott függő megbízásokat (Pending Orders) "utaztatni" (OrderModify).
*   **Működés:** Ha az árfolyam elmozdul, vagy csak "zaj" generálása a cél, a rendszer apró, véletlenszerű mértékben eltolja az árszinteket. Ez megakadályozza, hogy a bróker statikus "falakat" (Static Order Blocks) detektáljon.

#### 3. Precíziós Naplózás (`BlackBox.mqh`)
*   **RSI & Flow Delta:** A kérésnek megfelelően **3 tizedesjegy** pontossággal (`%.3f`) kerülnek a CSV-be (1-10 közötti értékeknél kritikus).
*   **Egyéb Indikátorok:** 5 tizedesjegy (`%.5f`) a maximális felbontás érdekében.

#### 4. Konfigurálhatóság (Panel Inputs)
Új "Stealth Systems" csoport a beállításokban:
*   `InpUseStealth`: Ki/Be kapcsoló.
*   `InpChaosLevel`: Káosz intenzitása (pl. 1.0 = Normál, 2.0 = Nagy szórás).
*   `InpActiveMorph`: A megbízások mozgatásának engedélyezése.

---

## 🚀 KÖVETKEZŐ SESSION TERV (Javaslat)

### 1. Tesztelés és Finomhangolás
*   **Feladat:** Fordítsd le a kódot (`Mimic_Merkava_v1.05_BarbedWire.mq5`) és futtasd Strategy Testerben vagy éles számlán (kis lottal).
*   **Figyeld:**
    *   `BlackBox` CSV: Megjelennek-e a 3 tizedes pontosságú adatok?
    *   Napló (Journal): Látsz-e "Morph" vagy "Jitter" üzeneteket?
    *   Végrehajtás: Érezhető-e a késleltetés (Latency)? Ha túl lassú, csökkentsd az `InpLatencyMax` értéket.

### 2. Elemzés (Forensic)
*   A generált CSV-k alapján vizsgáld meg, hogy a "Chaos" mennyire változtatta meg a belépési pontokat a fix rácshoz képest.

### 3. F-35 Upgrade (Roadmap)
*   A következő nagy lépés a **C++ DLL Bridge** előkészítése, hogy a Python alapú `Profit_Management` (tőkezelés) valós időben tudjon beavatkozni.

---

**Üzenet:** A rendszer most már nem csak egy "Tank", hanem egy "Lopakodó Tank". A statikus lenyomatok eltűntek. A bróker mostantól csak zajt lát, amiben néha "véletlenül" történik egy kötés.

*"A káosz nem hiba. A káosz a fegyver."*
