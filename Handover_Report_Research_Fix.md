# Kutatási Jelentés & Átadás (2026.01.24) - Kiegészítés

## 🔍 Kiegészítő Kutatási Eredmények (`rag_theory`)
A felhasználó kérésére mélyreható keresést végeztünk a `THEORY` adatbázisban a következő témákban:
1.  **Indikátor Hívások (`iCustom`):** A dokumentáció (`mql5book.txt`, `mql5.txt`) megerősíti, hogy az `iCustom` automatikusan próbálja megfeleltetni a paramétereket, ha az indikátor neve sztring konstansként van megadva.
2.  **Paraméter Átadás:** A "Parameter Shift" (elcsúszás) jelenségére, amelyet az `input group` okoz, **nincs explicit magyarázat** a hivatalos dokumentációban. Ez arra utal, hogy ez egy nem dokumentált viselkedés vagy platform-specifikus anomália ("undocumented behavior"), nem pedig a nyelv szándékolt tulajdonsága.
3.  **Következtetés:** Az empirikus (tapasztalati) megoldásunk – az `input group` sorok kikommentelése – műszakilag a legbiztosabb eljárás, mivel megszünteti a bizonytalansági tényezőt (a csoportnevek "láthatatlan" paraméterként való értelmezését).

## 🛠️ Jelenlegi Állapot (Stabil)
*   **EA:** `Mimic_Trap_Research_EA.mq5` (v2.00)
    *   Visszaállítva a `Hybrid_Conviction_Monitor`, `WVF` és `VA` használatára.
*   **Indikátor:** `Hybrid_Conviction_Monitor.mq5`
    *   **Javítva:** Az `input group` sorok ki vannak kommentelve.
    *   **Javítva:** Típuskonverziós (`int` cast) figyelmeztetések kezelve.

## 📝 Teendők / Ajánlás
Mivel a `THEORY` nem ad "tisztább" módszert az `input group` kezelésére `iCustom` hívásnál, a jelenlegi "Ungroup" megoldás a végleges javításnak tekinthető ebben a környezetben.
