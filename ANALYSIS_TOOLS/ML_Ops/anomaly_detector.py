import pandas as pd
import numpy as np
import time
import os
from sklearn.ensemble import IsolationForest
import joblib
import warnings
warnings.filterwarnings("ignore")

# TensorFLow AutoEncoder alapok importálása (Későbbi használatra / Éles V2-re)
# from tensorflow.keras.models import Model
# from tensorflow.keras.layers import Input, Dense

print("=== 🕵️ MERKAVA ML-OPS: NÉMA SZÍNHÁZ (ANOMÁLIA DETEKTOR) ===")

def load_data(filepath):
    print(f"[*] Adat betöltése: {filepath}...")
    try:
        # Az MQL5 CSV-je vesszővel elválasztott.
        df = pd.read_csv(filepath)

        # Oszlopnevek ellenőrzése
        expected_cols = ['TimeMsc', 'Bid', 'Ask', 'Spread', 'TickVolume', 'Ping']
        if not all(col in df.columns for col in expected_cols):
            print("[-] Hiba: A CSV nem tartalmazza a várt oszlopokat!")
            return None

        # Üres vagy hibás sorok dobása
        df.dropna(inplace=True)
        return df
    except Exception as e:
        print(f"[-] Hiba az adat beolvasásakor: {e}")
        return None

def feature_engineering(df):
    print("[*] Feature Engineering (Változók generálása)...")

    # 1. Delta Idő (Mennyi idő telt el a tickek között) - Késleltetések detektálására
    df['TimeDeltaMsc'] = df['TimeMsc'].diff().fillna(0)

    # 2. Árfolyam gyorsulás (Bid_Diff)
    df['Bid_Diff'] = df['Bid'].diff().fillna(0)

    # 3. Spread Volatilitás (Bróker kitágítja-e a spreadet hirtelen)
    df['Spread_Diff'] = df['Spread'].diff().fillna(0)

    # 4. Ping Tüske (Generál-e a bróker mű-lagot?)
    df['Ping_Diff'] = df['Ping'].diff().fillna(0)

    # A modell számára releváns feature-ök kiválasztása
    features = ['Bid_Diff', 'Spread', 'Spread_Diff', 'TickVolume', 'Ping', 'Ping_Diff', 'TimeDeltaMsc']
    return df, features

def train_isolation_forest(df, features):
    print("[*] Unsupervised Isolation Forest modell betanítása...")

    # Az Isolation Forest a scikit-learn beépített anomália-keresője.
    # Nem igényel címkézett adatokat (Unsupervised).
    # contamination = 0.01 -> Feltételezzük, hogy az adatok 1%-a anomália (bróker trükk).
    model = IsolationForest(n_estimators=100, contamination=0.01, random_state=42)

    X = df[features].values
    model.fit(X)

    # Elmentjük a modellt későbbi online predikcióhoz (VPS-en)
    joblib.dump(model, "isolation_forest_model.pkl")
    print("[+] Isolation Forest modell elmentve (isolation_forest_model.pkl)!")
    return model

def detect_anomalies(model, df, features):
    print("[*] Anomáliák keresése...")
    X = df[features].values

    # A predict -1-et ad vissza az anomáliákra, 1-et a normál adatokra.
    df['Anomaly'] = model.predict(X)
    df['Anomaly_Score'] = model.decision_function(X) # Mennyire normális (negatív = anomália)

    anomalies = df[df['Anomaly'] == -1]

    print(f"\n[+] Elemzés kész. Összes vizsgált Tick: {len(df)}")
    print(f"[!] Talált Anomáliák (Bróker Trükk Gyanú): {len(anomalies)} db ({(len(anomalies)/len(df))*100:.2f}%)")

    if len(anomalies) > 0:
        print("\nLegkritikusabb anomáliák (Legnegatívabb score-ok):")
        # Csak a legdurvábbakat írjuk ki (legkisebb score)
        worst_anomalies = anomalies.sort_values(by='Anomaly_Score').head(5)
        print(worst_anomalies[['TimeMsc', 'Bid', 'Ask', 'Spread', 'Ping', 'Anomaly_Score']])

        # Mentsük ki egy külön fájlba a Térképszoba számára
        anomalies.to_csv("Detected_Anomalies_Log.csv", index=False)
        print("\n[+] Anomáliák részletes naplója kimentve: Detected_Anomalies_Log.csv")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Merkava ML-Ops: Bróker Profilozó (Isolation Forest)")
    parser.add_argument("--csv", type=str, required=True, help="A Merkava_Naked_Sensor által generált CSV fájl útvonala")
    args = parser.parse_args()

    if not os.path.exists(args.csv):
        print(f"[-] Hiba: A megadott fájl nem található: {args.csv}")
        exit(1)

    df = load_data(args.csv)
    if df is not None:
        df, feature_cols = feature_engineering(df)
        # Ha kevés az adat, várjunk...
        if len(df) < 100:
            print("[-] Túl kevés adat a betanításhoz (min. 100 tick kell). Gyűjts tovább!")
        else:
            iso_model = train_isolation_forest(df, feature_cols)
            detect_anomalies(iso_model, df, feature_cols)
