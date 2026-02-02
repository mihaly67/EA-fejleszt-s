# VPS Tudásbázis Építési Útmutató (RDP / Desktop Verzió)

Ez az útmutató a **Github repo** nevű munkamappára van optimalizálva.

## 1. Mappaszerkezet Kialakítása (FileZilla vagy Asztal)
Hozz létre egy mappát a VPS-en (pl. az Asztalon) ezzel a névvel: `Github repo`.

Ebbe a mappába töltsd/másold be a következőket, **hogy egymás mellett legyenek**:

1.  **A Script:** `builder.py`
2.  **A Függőség:** `requirements.txt`
3.  **A Repók:** A kicsomagolt könyvtárak (pontos nevekkel!).
    *   `hummingbot-master`
    *   `FinRL-master`
    *   `vectorbt-master`
    *   `nautilus_trader-develop`
    *   `context7-master`

**Így kell kinéznie a mappának:**
```text
Github repo/
├── builder.py
├── requirements.txt
├── hummingbot-master/       (Mappa)
├── FinRL-master/            (Mappa)
├── vectorbt-master/         (Mappa)
├── nautilus_trader-develop/ (Mappa)
└── context7-master/         (Mappa)
```
*Fontos: A script automatikusan felismeri ezeket a mappákat, ha mellette vannak.*

## 2. Környezet Telepítése (Terminál)
Nyisd meg a Terminált, és telepítsd a Pythont (ha még nincs):

```bash
sudo apt update
sudo apt install python3 python3-pip -y
```

## 3. A Script Futtatása
A terminálban lépj be a mappába (ahová tetted):

```bash
# Példa, ha az Asztalra tetted:
cd "~/Desktop/Github repo"
```

Telepítsd a csúszkát:
```bash
pip3 install -r requirements.txt
```

Indítsd a gyártást:
```bash
python3 builder.py
```

## 4. Eredmény
A script végigfut, és ugyanebben a mappában létrehozza a fájlt:
**`knowledge_base_thiefs_library.jsonl`**

Ezt másold le a saját gépedre. Kész! 🚀
