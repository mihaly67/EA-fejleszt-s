# Handover Report - 2026.02.08 21:59
**Tárgy:** Merkava v2 Refaktorálás és a Hybrid Pulse Tizedesjegy-Rejtélye
**Státusz:** Részleges Siker (EA/Log rendben, de a vizuális indikátor "tizedes-hibája" fennáll)

## 📌 Összefoglaló (Mit végeztünk el?)
Ebben a sessionben a Barbed Wire 1.03-as stabil alapra építve létrehoztuk a **Merkava v2.xx** szériát, szigorúan követve a könyvtárszervezési és logolási elvárásokat.

1.  **Strukturális Refaktorálás (v2.00 - v2.05):**
    *   Létrehoztuk a `NavSystem` és `BlackBox` könyvtárak verziózott példányait az `Indicators/Indicators` mappában.
    *   Az EA (`Merkava_v2_05.mq5`) szabályosan hívja ezeket.
2.  **Zero Latency Logolás:**
    *   A `BlackBox` mostantól `tick.time_msc`-t használ elsődleges időbélyegként (Epoch 64-bit int), ami tökéletes a gépi tanuláshoz.
    *   Az indikátor értékek (`RSI`, `Flow`, `Hybrid`) `%.5f` precizitással kerülnek a CSV-be.
3.  **Flow MFI Javítás:**
    *   Sikeresen egyesítettük a Flow MFI-t egyetlen 0-100 közötti értékre, és megoldottuk a "Cold Start" (kezdeti nulla) problémát a volumen-akkumuláció javításával.
4.  **Vizualizáció és Cleanup:**
    *   Helyreállítottuk az indikátorok chartra tételét (`AttachToChart`), és implementáltunk egy agresszív takarítót (`CleanupChart`, `Release`), ami törli a szemetet leállításkor.

## ⚠️ A Megoldatlan Probléma: Hybrid Pulse (DeltaForce) Tizedesek
A logokban és a charton a Hybrid DF görbe értékei egész számként jelennek meg (pl. `53.00000`), a tizedesjegyek mindig nullák. Bár a kérést ("vizsgáld meg az indikátort") megkaptam, a javításom (átállás `CopyBuffer`-re) nem oldotta meg a gondot.

### Miért nem sikerült javítani? (Gyökérelemzés)
A hiba nem a logolásban, és nem is "kerekítési hibában" van, hanem a **matematikai definícióban**.
1.  A `Jules_Hybrid_Momentum_Pulse_v1.04.mq5` kódja így számol:
    ```cpp
    double diff = (close[i] - close[i+1]) / Point();
    ```
2.  A `Point()` a legkisebb lehetséges ármozgás (pl. BTCUSD-nél 0.01).
3.  **Matematikai tény:** Ha az ár csak `Point` többszöröseivel mozoghat, akkor az árváltozás osztva a `Point`-tal **mindig egész számot ad**. (Pl. Árváltozás: 0.15. Point: 0.01. Eredmény: 15.0).
4.  A DeltaForce görbe ezeket az egész számokat adja össze (`curr_h += diff`). Egész számok összege mindig egész szám.
5.  **Következtetés:** A jelenlegi indikátor logika szerint a DeltaForce görbe **definíció szerint nem tartalmazhat tizedeseket**, hacsak nem alkalmazunk rajta utólagos simítást (pl. átlagolást).

### Miért nem vettem észre?
Tévesen azt feltételeztem, hogy a `Point()` osztás lebegőpontos "zajt" vagy tört értékeket eredményez (mint pl. devizáknál néha előfordulhatna átlagolt gyertyáknál), de a `Close` ár mindig `Point`-ra illeszkedik, így az eredmény mindig kerek egész. Azt hittem, "casting" (típuskonverziós) hiba van, nem pedig a logika sajátossága.

## 🛠️ Következő Session Feladatai (v2.06)
A tizedesjegyek (finom felbontás) eléréséhez módosítanunk kell magát a `Jules_Hybrid_Momentum_Pulse` indikátort.

1.  **Indikátor Módosítása (v1.05):**
    *   Be kell vezetni egy **Simítást (Smoothing)** a DeltaForce görbére.
    *   Például: A nyers `df_raw` akkumuláció után futtatunk egy rövid periódusú (pl. 3-as) EMA-t vagy SMA-t a `BufferDFCurve` tömbön.
    *   Ez az átlagolás fogja létrehozni a kívánt tört értékeket (pl. `15` helyett `15.33333`), ami "élőbbé" teszi a görbét.
2.  **Merkava v2.06:**
    *   Frissíteni az EA-t, hogy az új (v1.05-ös) indikátort hívja be.

**Összegzés:** A rendszer stabil és logol, de a Hybrid görbe "darabossága" (egész számok) csak az indikátor-logika bővítésével (simítás) oldható fel.
