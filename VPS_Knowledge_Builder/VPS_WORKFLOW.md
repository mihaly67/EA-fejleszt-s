# VPS Tudásbázis Építési Útmutató (Knowledge Builder Guide)

Ez a dokumentum lépésről lépésre leírja, hogyan telepítsd és futtasd a "Tudás Építő" rendszert a Linux VPS-eden.

## 0. Előkészületek (A PC-den)
Mielőtt csatlakoznál a VPS-hez, legyenek kéznél a következők:
1.  **A Repók:** Az 5 letöltött GitHub repository (Hummingbot, FinRL, stb.) egy ZIP fájlban, vagy mappákban.
2.  **A Tool Kit:** Ebből a könyvtárból a `builder.py` és a `requirements.txt`.
3.  **FileZilla (vagy WinSCP):** A fájlok feltöltéséhez.

## 1. Csatlakozás a VPS-hez (SSH)
Nyiss egy terminált (vagy Putty-ot) és lépj be:

```bash
ssh user@your-vps-ip
# Add meg a jelszavadat, ha kéri
```

## 2. Környezet Előkészítése (Telepítés)
Frissítsd a rendszert és telepítsd a szükséges alapokat (Python, Unzip). Futtasd ezeket a parancsokat sorban:

```bash
# Rendszer frissítése
sudo apt update && sudo apt upgrade -y

# Python és PIP telepítése (ha nincs)
sudo apt install python3 python3-pip unzip -y

# Munkakönyvtár létrehozása
mkdir -p ~/knowledge_builder
cd ~/knowledge_builder
```

## 3. Fájlok Feltöltése (FileZilla)
Most nyisd meg a FileZilla-t, csatlakozz a VPS-hez (SFTP mód, 22-es port).
Navigálj a `/home/user/knowledge_builder` (vagy `/root/knowledge_builder`) könyvtárba.

Töltsd fel ide a következőket:
1.  `builder.py` (A scriptünk)
2.  `requirements.txt` (A függőségek listája)
3.  Az 5 Repository ZIP fájljait (vagy a mappáikat).
    *   *Tipp: Ha egy nagy "repos_master.zip"-ed van, töltsd fel azt.*

## 4. Kicsomagolás
Térj vissza az SSH terminálhoz (`cd ~/knowledge_builder`).

Ha ZIP-ben vannak a repók, csomagold ki őket:

```bash
# Példa: Ha mindegyik külön zip
unzip hummingbot.zip
unzip finrl.zip
# ... stb

# VAGY Ha egy nagy zipben vannak:
unzip repos_master.zip
# Majd ha belül is zipek vannak:
unzip "*.zip"
```

**FONTOS:** A `ls -F` parancs kiadásakor látnod kell az 5 könyvtárat (pl. `hummingbot/`, `FinRL/`, `vectorbt/`...). A script ezeket a neveket keresi!

## 5. Python Csomagok Telepítése
Telepítsd a folyamatjelzőt (`tqdm`):

```bash
pip3 install -r requirements.txt
# Vagy manuálisan:
pip3 install tqdm
```

## 6. A Script Futtatása (Az Építés)
Indítsd el a scriptet. Látni fogsz egy folyamatjelző csíkot.

```bash
python3 builder.py
```

Kimenet:
> 🔍 Scanning directories...
> ✅ Found 12450 valid files to process.
> 🚀 Processing...
> [████████████████████] 100% | 12450/12450 [00:45<00:00, 275.12 file/s]
> 💾 Writing to disk...
> === ✅ BUILD COMPLETE ===
> 📦 Output: knowledge_base_thiefs_library.jsonl

## 7. Letöltés
Ha végzett, a mappában létrejött a `knowledge_base_thiefs_library.jsonl`.
Frissítsd a FileZilla nézetet, és töltsd le ezt a fájlt a számítógépedre.

Ezzel kész is vagy! 🚀
