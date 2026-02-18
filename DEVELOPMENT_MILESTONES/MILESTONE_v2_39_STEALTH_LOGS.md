# Mérföldkő Dokumentáció (Stealth Logs Upgrade) - v2.39

**Dátum:** 2026.02.18
**Státusz:** STABIL (Termelési Kész)

Ez a dokumentum rögzíti a **Merkava v2.39**, a **FireControl v2.24** és a **StealthRegistry v1.06** konfigurációs állapotát. Ez a verzió teljes körűen orvosolja a stealth hiányosságokat (üres bróker komment) ÉS a hiányzó naplózási problémákat (CSV fájlok nem jöttek létre, hiányzó oszlop).

**FONTOS:** Minden fájl verziózva lett a fájlnevében is, a korábbi kaotikus állapot megszüntetése érdekében.

## 1. Rendszer Komponensek (Verziók)

*   **Fő Program (Expert Advisor):**
    *   `Merkava_v2_39.mq5` (Verzió: 2.39)
    *   *Funkciók:* Deep Stealth + **Robusztus Audit Naplózás**.
    *   *Includes:* Minden külső könyvtár verziószámmal hivatkozva.

*   **Végrehajtó Modulok:**
    *   `FireControl_v2_24.mqh` (Verzió: 2.24)
        *   *Fix:* Üres komment küldése a brókernek.
        *   *Fix:* A belső stratégiai címkét (pl. `_L1`) külön paraméterként adja át a Registry-nek.
    *   `StealthRegistry_v1_06.mqh` (Verzió: 1.06)
        *   *Fix:* **CSV Fájl Készítés Javítva.** `FILE_SHARE_READ|FILE_SHARE_WRITE` flag-ek használata a fájl zárolási hibák elkerülésére.
        *   *Feature:* **Új Oszlop: StrategyTag.** A `Logs/Stealth_Audit_*.csv` fájlban mostantól külön oszlop tartalmazza a belső címkét (pl. `Merkava_L1`).
    *   `StealthEngine_v1_0.mqh` (Verzió: 1.0)
        *   *Rename:* Az eredeti `StealthEngine.mqh` átnevezve a szigorú verziókövetés miatt.
    *   `PhysicsEngine_v1_0.mqh` (Verzió: 1.0)
        *   *Rename:* Szintén átnevezve.

## 2. Változások a v2.38-hoz képest

### 🚨 Szigorú Verziókövetés (Chaos Fix)
Minden fájl (`StealthEngine`, `PhysicsEngine`, `Test_StealthLogs`) átnevezésre került, hogy a fájlnév tartalmazza a verziószámot. Ez megakadályozza, hogy a jövőbeli fejlesztések felülírják a működő "Golden Standard" állapotokat.

### 🚨 Naplózási Javítások
1.  **Log Fájlok:** A rendszer mostantól agresszívebben próbálja létrehozni a `MQL5/Files/Merkava_Stealth/Logs/` mappát, és ha nem sikerül, a gyökérbe (`MQL5/Files/`) ment fallback fájlként.
2.  **StrategyTag Oszlop:** A CSV fájl szerkezete bővült:
    `Time,Action,Ticket,MagicNumber,Comment,StrategyTag`
    *   `Comment`: Amit a bróker lát (pl. `""` vagy `"manual"`).
    *   `StrategyTag`: A belső azonosító (pl. `Merkava_L1`).

### Ellenőrzés (Test Script)
Mellékeltünk egy `Test_StealthLogs_v1_00.mq5` scriptet. Futtatásával azonnal ellenőrizhető, hogy a rendszer tud-e írni a lemezre.

## 3. Telepítés és Fájlok

*   EA: `MQL5/Indicators/Jules/Merkava_v2_39.mq5`
*   FireControl: `MQL5/Indicators/Indicators/FireControl_v2_24.mqh`
*   Registry: `MQL5/Indicators/Indicators/StealthRegistry_v1_06.mqh`
*   Engine: `MQL5/Indicators/Indicators/StealthEngine_v1_0.mqh`

**Jóváhagyta:** Jules (AI Engineer) & Rendszerfőnök
