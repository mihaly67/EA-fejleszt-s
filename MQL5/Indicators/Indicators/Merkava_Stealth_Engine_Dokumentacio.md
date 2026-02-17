# Merkava Stealth Engine: Műszaki Dokumentáció (v1.0)

**Dátum:** 2026.02.16
**Fájl:** `MQL5/Indicators/Indicators/StealthEngine.mqh`
**Osztály:** `CStealthEngine`
**Cél:** Emberi viselkedés szimulációja az MQL5 `OrderSend` hívások burkolásával.

---

## 1. Bevezetés
A `CStealthEngine` egy MQL5 osztály, amely célja, hogy az Expert Advisor (EA) kereskedési viselkedését "emberibbé" tegye, ezáltal megnehezítve a brókerek számára a gépi profilozást (algo detection). Nem módosítja a stratégia belépési/kilépési logikáját, csupán a *végrehajtás módját* (időzítés, árfolyam pontosság, metaadatok).

## 2. API Referencia

### `Init(bool enabled, int base_delay_ms, int jitter_ms)`
Inicializálja a modult.
*   `enabled`: `true` esetén a stealth funkciók aktívak. `false` esetén átlátszó (transparent) módban működik (nincs késleltetés, nincs zaj).
*   `base_delay_ms`: Az alapvető várakozási idő milliszekundumban (pl. 400ms).
*   `jitter_ms`: A véletlenszerű ingadozás mértéke (pl. 150ms). A tényleges késleltetés `base +/- jitter` tartományban lesz.

### `ApplyHumanDelay()`
Véletlenszerű várakozást (Sleep) hajt végre a beállított paraméterek alapján.
*   **Használat:** Hívja meg közvetlenül az `OrderSend` előtt.
*   **Működés:** `Sleep(BaseDelay + Random(-Jitter, +Jitter))`

### `GetFuzzyPrice(double price, double point)`
Hozzáad egy véletlenszerű "zajt" (micro-pips) az árhoz.
*   `price`: Az eredeti (számított) árfolyam.
*   `point`: A szimbólum pontértéke (`_Point`).
*   **Visszatérés:** `price +/- (0..2 * point)`.
*   **Cél:** Elkerülni a kerek számoknál vagy a pontos indikátor-értékeknél történő "tömeges" belépést.

### `GetHumanComment()`
Visszaad egy véletlenszerűen kiválasztott, emberi hatású megjegyzést.
*   **Lista:** `""` (üres), `"manual"`, `"t1"`, `"test"`, `"news"`, `"kezi"`.
*   **Cél:** Megtéveszteni azokat a bróker algoritmusokat, amelyek az EA-specifikus kommenteket (pl. "Merkava_v2.30") keresik.

### `IsFatFinger()`
Szimulál egy ritka "kövér ujj" (fat finger) hibát.
*   **Valószínűség:** 0.1% (1 az 1000-hez).
*   **Használat:** Ha `true`, az EA *szándékosan* ronthatja az árat vagy a lotméretet egy minimális mértékben (opcionális, magas kockázatú funkció).

## 3. Integrációs Példa (Merkava EA)

```mql5
#include <Indicators/StealthEngine.mqh>

CStealthEngine Stealth;

int OnInit()
{
   // Stealth mód aktiválása: 400ms átlagos késleltetés, +/- 150ms ingadozás
   Stealth.Init(true, 400, 150);
   return(INIT_SUCCEEDED);
}

void OpenTrade()
{
   // 1. Emberi késleltetés
   Stealth.ApplyHumanDelay();

   // 2. Árfolyam "zajosítása" (pl. Stop Loss)
   double sl = Stealth.GetFuzzyPrice(calculated_sl, _Point);

   // 3. Emberi megjegyzés
   string comment = Stealth.GetHumanComment();

   // 4. Megbízás küldése
   trade.PositionOpen(Symbol(), ORDER_TYPE_BUY, lot, price, sl, tp, comment);
}
```

## 4. Stratégiai Megfontolások
*   **Latency:** A Stealth Engine szándékosan lassítja a végrehajtást. HFT (High-Frequency Trading) stratégiákhoz **NEM** ajánlott.
*   **Broker Profiling:** A modul nem garantálja a láthatatlanságot, de jelentősen növeli a zajt a bróker adatbázisában, megnehezítve a statisztikai alapú detektálást.
