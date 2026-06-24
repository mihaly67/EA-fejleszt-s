import os
import glob
import pandas as pd
import numpy as np
import logging
import json

# Alap loggolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def calculate_global_volatility(data_dir: str, output_dir: str):
    """
    Feldolgozza a 'Global_Ticks' CSV(ke)t, kiszámítja az abszolút volatilitási határokat
    (a nyers Bid árak 500 tickes mozgószórása alapján), és létrehoz egy 1-5 skálát.
    """
    logger.info("🌍 Globális Volatilitás Horgony (Global Anchor) Kalkulátor indítása...")

    # Keresünk 'Global_Ticks' fájlokat. Ha nincs, megpróbáljuk az összes csv-t
    csv_files = glob.glob(os.path.join(data_dir, "*Global_Ticks*.csv"))
    if not csv_files:
        logger.warning(f"Nem találtam 'Global_Ticks' végződésű fájlokat a {data_dir} mappában.")
        csv_files = [f for f in glob.glob(os.path.join(data_dir, "*.csv"))
                     if not os.path.basename(f).startswith("ANALYZED_")
                     and not os.path.basename(f).startswith("MATRIX_ANALYZED_")
                     and not os.path.basename(f) == "mock_tick_data.csv"]

    if not csv_files:
        logger.error("Nincsenek CSV fájlok a volatilitás skála kiszámításához!")
        return

    logger.info(f"Összesen {len(csv_files)} db CSV fájlt fogok beolvasni az 'Ősrobbanás' (Baseline) skálához.")

    all_volatility_values = []
    symbol = "UNKNOWN"

    # Fájlnevekből kinyerjük az instrumentumot, ha lehetséges (pl. XAUUSD_Global_Ticks...)
    for file_path in csv_files:
        base_name = os.path.basename(file_path)
        if "Global_Ticks" in base_name:
            symbol = base_name.split("_")[0]
            break

    # 1. Adatok begyűjtése
    for file_path in csv_files:
        logger.info(f"Fájl feldolgozása: {os.path.basename(file_path)}...")
        try:
            # Csak a Bid oszlopra van szükségünk, így kíméljük a RAM-ot
            df = pd.read_csv(file_path, usecols=lambda c: 'Bid' in c or 'bid' in c.lower())

            # Megkeressük a tényleges Bid oszlopot
            bid_col = [c for c in df.columns if 'bid' in c.lower()]
            if not bid_col:
                logger.warning(f"Nem találtam Bid oszlopot a {os.path.basename(file_path)} fájlban. Kihagyom.")
                continue

            bid_col = bid_col[0]

            # Kiszámoljuk az 500 tickes gördülő szórást (Volatilitás)
            # A min_periods=10 biztosítja, hogy az elején lévő adatok is kapjanak valamilyen értéket
            volatility = df[bid_col].rolling(window=500, min_periods=10).std().fillna(0).values

            # Csak a valós (>0) értékeket tartjuk meg
            valid_volatility = volatility[volatility > 0]
            all_volatility_values.extend(valid_volatility)

        except Exception as e:
            logger.error(f"Hiba a fájl olvasása közben ({file_path}): {e}")

    if not all_volatility_values:
        logger.error("Nem sikerült érvényes volatilitási adatot kinyerni. A skálázás megszakítva.")
        return

    # 2. Skála kiszámítása (Percentilisekkel az extrém kiugrások kiszűrésére)
    logger.info("📊 Volatilitási adatok egyesítése és zajszűrése...")
    vol_array = np.array(all_volatility_values)

    # Kiszűrjük az alsó és felső 1%-ot, hogy az abszolút extrém anomáliák
    # (pl. bróker fagyás, vagy 1 tickes irreális ugrás) ne torzítsák el a skálát
    min_vol = np.percentile(vol_array, 1)
    max_vol = np.percentile(vol_array, 99)

    logger.info(f"Abszolút Minimum (Zajszűrt): {min_vol:.6f}")
    logger.info(f"Abszolút Maximum (Zajszűrt): {max_vol:.6f}")

    # Létrehozzuk az 5 osztályt lineáris felosztással a Min és Max között
    # (Ha elosztás-alapú, logaritmikus skálát szeretnénk később, az is könnyen implementálható)
    step = (max_vol - min_vol) / 5.0

    # Class 1: Min -> Min + Step (Pangó/Döglött Piac)
    # Class 2: ... -> Min + 2*Step (Csendes)
    # Class 3: ... -> Min + 3*Step (Átlagos)
    # Class 4: ... -> Min + 4*Step (Aktív)
    # Class 5: ... -> Max (Extrém Volatilis)

    scale_dict = {
        "Symbol": symbol,
        "Classes": {
            "Class_1_Dead":     {"lower_bound": 0.0,                        "upper_bound": float(min_vol + step)},
            "Class_2_Quiet":    {"lower_bound": float(min_vol + step),      "upper_bound": float(min_vol + 2*step)},
            "Class_3_Average":  {"lower_bound": float(min_vol + 2*step),    "upper_bound": float(min_vol + 3*step)},
            "Class_4_Active":   {"lower_bound": float(min_vol + 3*step),    "upper_bound": float(min_vol + 4*step)},
            "Class_5_Extreme":  {"lower_bound": float(min_vol + 4*step),    "upper_bound": float('inf')}
        },
        "Statistics": {
            "Data_Points": int(len(vol_array)),
            "Absolute_Min_1%": float(min_vol),
            "Absolute_Max_99%": float(max_vol),
            "Median": float(np.median(vol_array)),
            "Mean": float(np.mean(vol_array))
        }
    }

    # 3. Kimentés JSON (Gépnek) és TXT (Embernek) formátumban
    os.makedirs(output_dir, exist_ok=True)
    json_path = os.path.join(output_dir, f"{symbol}_Volatility_Scale.json")
    txt_path = os.path.join(output_dir, f"REPORT_{symbol}_Volatility_Scale.txt")

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(scale_dict, f, indent=4)

    # TXT generálása
    with open(txt_path, 'w', encoding='utf-8') as f:
        f.write(f"=== GLOBÁLIS VOLATILITÁS SKÁLA ({symbol}) ===\n")
        f.write(f"Elemzett adatpontok (tickek): {scale_dict['Statistics']['Data_Points']}\n")
        f.write(f"Zajszűrt Minimum: {scale_dict['Statistics']['Absolute_Min_1%']:.6f}\n")
        f.write(f"Zajszűrt Maximum: {scale_dict['Statistics']['Absolute_Max_99%']:.6f}\n")
        f.write(f"Átlag: {scale_dict['Statistics']['Mean']:.6f} | Medián: {scale_dict['Statistics']['Median']:.6f}\n\n")
        f.write(f"--- AZ 5-ÖS SKÁLA (A Mátrix Profilozó ezt használja) ---\n")
        for class_name, bounds in scale_dict["Classes"].items():
            f.write(f"  - {class_name:15}: {bounds['lower_bound']:.6f} -> {bounds['upper_bound']:.6f}\n")

    logger.info("--------------------------------------------------")
    logger.info(f"🎉 SIKER! Globális Volatilitás Skála (1-5) létrehozva!")
    logger.info(f"📁 Gép-olvasható Mentve ide: {json_path}")
    logger.info(f"📄 Ember-olvasható Mentve ide: {txt_path}")
    for class_name, bounds in scale_dict["Classes"].items():
        logger.info(f"  - {class_name}: {bounds['lower_bound']:.6f} -> {bounds['upper_bound']:.6f}")
    logger.info("Ezt a skálát fogja használni a Mátrix Profilozó az egységes besoroláshoz.")
    logger.info("--------------------------------------------------")

if __name__ == '__main__':
    # Helyi struktúra a repo szerint
    base_dir = os.path.dirname(os.path.abspath(__file__))
    data_dir = os.path.join(base_dir, 'data')
    output_dir = os.path.join(base_dir, 'data', 'analyzed')

    calculate_global_volatility(data_dir, output_dir)
