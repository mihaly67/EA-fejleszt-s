# Átadás-átvételi Jelentés - 2026.01.24
**Állapot:** Stabil / Helyreállítva
**Verzió:** Mimic_Trap_Research_EA v2.00 (Javított Indikátorral)

## 📌 Helyzetkép
A rendszer vissza lett állítva a legutolsó ismert stabil állapotba, ahol a `Mimic_Trap_Research_EA` sikeresen működik együtt a `Hybrid_Conviction_Monitor` indikátorral.

## 🛠️ Elvégzett Javítások (Összefoglaló)

### 1. Hybrid_Conviction_Monitor.mq5 (A "Rejtély" Megoldása)
*   **Probléma:** Amikor az EA meghívta az indikátort (`iCustom`), a paraméterek értékei elcsúsztak (pl. a `13` bekerült a `5`-ös helyére), mert az `input group` használata megzavarta az MT5 belső paraméter-átadási mechanizmusát.
*   **Megoldás:** Az `input group` sorok kikommentelésre kerültek (`// input group ...`).
*   **Eredmény:** A paraméterek listája "lapos" lett, így az EA által küldött értékek pontosan a megfelelő változókba kerülnek.
*   **Extra:** Kijavítottuk a "sign mismatch" (előjel hiba) fordítói figyelmeztetéseket is explicit `(int)` konverzióval.

### 2. Mimic_Trap_Research_EA.mq5
*   **Állapot:** Visszaállítva a **v2.00** verzióra.
*   **Aktív Indikátorok:**
    1.  `WVF` (Showcase)
    2.  `Hybrid_Conviction_Monitor` (Showcase - Javított)
    3.  `Hybrid_Velocity_Acceleration_VA` (VA)
*   **Eltávolítva:** A `Test_Group_...` diagnosztikai fájlok törlésre kerültek a tiszta környezet érdekében.

## ⚠️ Fontos Tudnivalók a Jövőre
1.  **Input Group Használata:** Ha egy indikátort EA-ból (`iCustom`) hívunk meg, **KERÜLJÜK** az `input group` használatát az indikátorban, vagy készüljünk fel arra, hogy a paraméterek sorrendje megváltozhat. A legbiztosabb módszer a csoportok mellőzése ezeknél a fájloknál.
2.  **Kutatás:** A vizsgálat bebizonyította, hogy bár a dokumentáció nem tiltja expliciten, a gyakorlatban (empirikusan) az `input group` zavart okozhat az automatizált hívásoknál.

## ✅ Teendők
A rendszer készen áll a további tesztelésre vagy fejlesztésre a stabil v2.00 alapról.
