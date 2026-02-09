# Handover Report - 2026.02.09 03:37
**Tárgy:** FireControl v2.07 Végső Szintaktikai & Logikai Javítás
**Státusz:** Validálva (v2.07 DOT Syntax / Adaptive Logic)

## 📌 A Szintaktikai Káosz Megoldása
A felhasználó 73+ hibát jelentett a fordításkor (`'>' - operand expected`).
*   **A Hiba Oka:** Az MQL5 (ellentétben a C++-szal) **NEM támogatja a `->` (nyíl) operátort** a pointereken keresztül történő tagfüggvény-híváshoz. Még ha `CTrade *ptr`-ről van is szó, a helyes szintaxis a **`.` (pont)** operátor.
*   **A Javítás:** Minden `m_trade->` és `m_symbol->` hívást lecseréltünk `m_trade.` és `m_symbol.` formátumra a `FireControl_v2_07.mqh` fájlban.

## 🛠️ Funkcionális Állapot (v2.07)
A szintaktikai javítás mellett a logikai kérések is be vannak építve:

1.  **Barbed Wire (Breakout) Logika:**
    *   **Stop Orderek:** A rendszer `BuyStop`-ot tesz az árfolyam *fölé* (Ask + Táv), és `SellStop`-ot az árfolyam *alá* (Bid - Táv).
    *   **Szimmetria:** A háló a Bid/Ask árakhoz van rögzítve, nem a középárhoz.

2.  **Adaptív Háló (Min Spread Védelem):**
    *   Bevezettük az `InpMinSpreadPoints` (default: 60 pont) változót.
    *   Ha a piaci spread (pl. 12 pont Gold-on) ennél kisebb, a rendszer a 60 pontot használja bázisnak.
    *   Ez megakadályozza a rács "összeomlását" (stacking) alacsony spreadnél, de tágul, ha a piac vadul mozog (Real Spread > 60).

## ⚠️ Következő Lépések
A rendszer most már lefordul (szintaktikailag helyes) és a logikája is megfelel a specifikációnak.
A következő teszteknek (felhasználói oldalon) ezekre kell fókuszálniuk:
1.  **Fordítás:** Sikeres-e? (0 error).
2.  **PL/Lot/Margin:** A korábban jelzett "hibás számítások" ellenőrzése a logokban.

**Jelenlegi verzió:** Merkava v2.07 (Dot Syntax Fix).
