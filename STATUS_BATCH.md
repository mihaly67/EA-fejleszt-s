# Rendszer Frissítés: Szakaszos (Batch) Üzemmód

**Állapot:** 🟢 AKTÍV (Subprocess Architektúra)

**Fejlesztések:**
1.  **Erőforrás Menedzsment:** A Műszakvezető mostantól nem tartja állandóan memóriában a mesterséges intelligenciát. Minden egyes kutatási feladathoz külön "Munkást" (subprocess) indít, majd a feladat végén felszabadítja a memóriát.
2.  **Szakaszos Működés (Cooldown):** Minden részfeladat után a rendszer pihenőt tart (alapértelmezett: 60 mp), hogy elkerülje a túlterhelést.
3.  **Stabilitás:** Ez a megoldás (Subprocess + Watchdog) garantálja a maximális stabilitást hosszú távú, felügyelet nélküli futáshoz.

**Jelenlegi Feladat:** `Trading_Assistant_Batch_01` (3 részfeladat)
-   Matematikai könyvtárak
-   Rezsim detektálás
-   Dashboard GUI

A jelentés a `project_reports/` mappában fog megjelenni, amint az első szakasz elkészül.
