# MQL5 File Map Generator (Python Script)

## 📌 Cél
Ez a script (`generate_mql5_filemap.py`) arra szolgál, hogy feltérképezze az Ön MQL5 könyvtárának pontos szerkezetét (fájlnevek, elérési utak) anélkül, hogy a fájlok tartalmát kiolvasná. Ez lehetővé teszi az ügynök (Jules) számára, hogy ismerje a "terepet" és helyes include útvonalakat használjon.

## 🛠️ Előfeltételek (Prerequisites)
A script futtatásához **Python 3** szükséges.
(Linux/Ubuntu VPS esetén általában alapértelmezetten telepítve van).

### Ellenőrzés:
Nyisson egy terminált és írja be:
```bash
python3 --version
```
Ha verziószámot lát (pl. `Python 3.8.10`), akkor minden rendben.

## 🚀 Futtatás (Execution)

1.  Helyezze el a `generate_mql5_filemap.py` fájlt **közvetlenül a `MQL5` mappa mellé** (tehát ne bele, hanem egy szinttel feljebb).
    *   Példa struktúra:
        ```text
        /home/user/metatrader/
        ├── MQL5/          <-- Ez a célkönyvtár
        │   ├── Experts/
        │   └── Indicators/
        └── generate_mql5_filemap.py  <-- Ez a script
        ```

2.  Futtassa a scriptet:
    ```bash
    python3 generate_mql5_filemap.py
    ```

3.  Ha a mappa neve nem `MQL5`, akkor adja meg paraméterként:
    ```bash
    python3 generate_mql5_filemap.py "MappaNeve"
    ```

## 📦 Eredmény (Output)
A script két fájlt hoz létre ugyanabban a könyvtárban:
1.  `MQL5_FileMap.json` (A részletes térkép szöveges formátumban).
2.  `MQL5_FileMap.json.zip` (Tömörített változat).

## 📤 Feltöltés
Kérjük, töltse fel a **`MQL5_FileMap.json.zip`** fájlt a Drive-ra vagy küldje el az ügynöknek.
Ez a fájl **nem tartalmaz forráskódot**, csak a fájlok listáját és méretét. Biztonságos.
