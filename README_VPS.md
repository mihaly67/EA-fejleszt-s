# Universal Knowledge Capsule Builder - VPS Használati Útmutató

Ez a script arra való, hogy bármilyen mappastruktúrából (pl. GitHub repókból) egyetlen, tömörített **Tudáskapszulát** (`.jsonl.zip`) készítsen.

## 1. Előkészületek (Ubuntu VPS)

Ha még nincs Python telepítve:
```bash
sudo apt update
sudo apt install python3 python3-pip -y
```

Másold fel a következő fájlokat a VPS-re, **ugyanabba a mappába**, ahol a feldolgozni kívánt repók/mappák vannak:
- `universal_builder.py` (A script)
- `requirements.txt` (Függőségek listája)

Példa struktúra:
```
/home/user/my_knowledge_base/
├── universal_builder.py
├── requirements.txt
├── hummingbot/       (Repó mappa 1)
├── nautilus_trader/  (Repó mappa 2)
└── my_strategy/      (Saját kódok)
```

## 2. Telepítés

Nyiss terminált abban a mappában, ahol a fájlok vannak, és futtasd:

```bash
pip3 install -r requirements.txt
```
*(Ez telepíti a `tqdm` csomagot a folyamatjelzőhöz. Ha nem fut le, használd a `pip install tqdm` parancsot.)*

## 3. Futtatás

Indítsd el a scriptet:

```bash
python3 universal_builder.py
```

A script automatikusan:
1.  Megkeresi az összes mappát maga mellett (kivéve a rendszermappákat).
2.  Kigyűjti a releváns forráskódokat és dokumentációkat (`.py`, `.mq5`, `.md`, `.cpp`, stb.).
3.  Létrehozza az `output.jsonl` fájlt (minden sor egy fájl tartalma JSON formátumban).
4.  Becsomagolja az egészet egy `knowledge_capsule.zip` fájlba.

## 4. Befejezés

Ha a script végzett ("BUILD COMPLETE"), nevezd át a létrejött ZIP fájlt a tudásbázisod nevére:

```bash
mv knowledge_capsule.zip my_new_knowledge.zip
```

Most már letöltheted és használhatod a kapszulát!
