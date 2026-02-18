# Mérföldkő Dokumentáció (Stealth Logs Upgrade) - v2.39

**Dátum:** 2026.02.18
**Státusz:** STABIL (Termelési Kész)

Ez a dokumentum rögzíti a **Merkava v2.39**, a **FireControl v2.24** és a **StealthRegistry v1.06** konfigurációs állapotát. Ez a verzió teljes körűen orvosolja a stealth hiányosságokat (üres bróker komment) ÉS a hiányzó naplózási problémákat (CSV fájlok nem jöttek létre, hiányzó oszlop).

## 1. Rendszer Komponensek (Verziók)

*   **Fő Program (Expert Advisor):**
    *   `Merkava_v2_39.mq5` (Verzió: 2.39)
    *   *Funkciók:* Deep Stealth + **Robusztus Audit Naplózás**.

*   **Végrehajtó Modulok:**
    *   `FireControl_v2_24.mqh` (ÚJ - Verzió: 2.24)
        *   *Fix:* Üres komment küldése a brókernek.
        *   *Fix:* A belső stratégiai címkét (pl. `_L1`) külön paraméterként adja át a Registry-nek.
    *   `StealthRegistry_v1_06.mqh` (ÚJ - Verzió: 1.06)
        *   *Fix:* **CSV Fájl Készítés Javítva.** `FILE_SHARE_READ|FILE_SHARE_WRITE` flag-ek használata a fájl zárolási hibák elkerülésére.
        *   *Feature:* **Új Oszlop: StrategyTag.** A `Logs/Stealth_Audit_*.csv` fájlban mostantól külön oszlop tartalmazza a belső címkét (pl. `Merkava_L1`), míg a `Comment` oszlop azt mutatja, amit a bróker lát (vagyis üreset).
        *   *Safety:* Ékezetmentesített és tisztított fájlnevek a Windows kompatibilitás érdekében.

## 2. Változások a v2.38-hoz képest

### 🚨 Naplózási Javítások
A felhasználói visszajelzés alapján a v2.38-as javítás ugyan eltüntette a kommentet a bróker elől, de a belső CSV fájlok nem jöttek létre, és hiányzott a visszakereshetőség.

**Megoldás (v2.39):**
1.  **Log Fájlok:** A rendszer mostantól agresszívebben próbálja létrehozni a `MQL5/Files/Merkava_Stealth/Logs/` mappát, és ha nem sikerül, a gyökérbe (`MQL5/Files/`) ment fallback fájlként.
2.  **StrategyTag Oszlop:** A CSV fájl szerkezete bővült:
    `Time,Action,Ticket,MagicNumber,Comment,StrategyTag`
    *   `Comment`: Amit a bróker lát (pl. `""` vagy `"manual"`).
    *   `StrategyTag`: A belső azonosító (pl. `Merkava_L1`).

### Ellenőrzés (Test Script)
Mellékeltünk egy `Test_StealthLogs.mq5` scriptet. Futtatásával azonnal ellenőrizhető, hogy a rendszer tud-e írni a lemezre.

## 3. Telepítés és Fájlok

*   EA: `MQL5/Indicators/Jules/Merkava_v2_39.mq5`
*   FireControl: `MQL5/Indicators/Indicators/FireControl_v2_24.mqh`
*   Registry: `MQL5/Indicators/Indicators/StealthRegistry_v1_06.mqh`

A korábbi mérföldkő dokumentumok (v2.37, v2.38) elavultak.

**Jóváhagyta:** Jules (AI Engineer) & Rendszerfőnök
