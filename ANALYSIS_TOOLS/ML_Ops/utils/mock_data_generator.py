import pandas as pd
import numpy as np
import os
import gc
from datetime import datetime, timedelta

def create_mock_tick_data(filepath="data/mock_tick_data.csv", rows=5000):
    """
    Generál egy 'Naked Sensor' stílusú, nyers tick adathalmazt, amivel biztonságosan tesztelhetjük a
    memória-hatékony csővezetékünket a 8GB RAM-os környezetben, anélkül, hogy tényleges 1GB-os CSV-t
    kellene letöltenünk és használnunk.
    """
    print(f"🔧 Generálom a szintetikus MT5 tick adatokat ({rows} sor)...")

    np.random.seed(42)
    start_time = datetime(2026, 1, 1, 9, 0, 0)

    # Időbeli delta (ezüst golyó az event-driven struktúrához)
    time_deltas = np.random.randint(10, 1500, size=rows) # milliszekundumok (tick burstök és csend)
    time_msc_list = []
    current_time = start_time
    current_msc = int(start_time.timestamp() * 1000)

    for dt in time_deltas:
        current_msc += dt
        time_msc_list.append(current_msc)

    # Árfolyam generálása bolyongással (Random Walk)
    base_price = 1.08500
    price_changes = np.random.normal(0, 0.00005, size=rows)
    bids = base_price + np.cumsum(price_changes)

    # Spread manipuláció beoltása (Az anomália detektornak kell majd megtalálnia)
    # Normál spread 10-20 pont között, Anomália: hirtelen 50-100 pontos ugrás (pl. hírek vagy toxikus bróker)
    spreads = np.random.randint(10, 25, size=rows)
    # 2%-ban "Brokery Magic" - 80-120 pontos indokolatlan spread
    anomaly_indices = np.random.choice(rows, size=int(rows * 0.02), replace=False)
    for idx in anomaly_indices:
        spreads[idx] = np.random.randint(80, 150)

    asks = bids + (spreads / 100000)

    # Ping késleltetés beoltása (Szintén anomália teszthez)
    # Normál: 20-40ms, Anomália: 250-500ms
    pings = np.random.randint(20, 45, size=rows)
    for idx in anomaly_indices:
        pings[idx] = np.random.randint(250, 600)

    # Volumecégek (MT5 Tick Volume)
    bid_vols = np.random.randint(1, 15, size=rows)
    ask_vols = np.random.randint(1, 15, size=rows)

    df = pd.DataFrame({
        "TickMSC": time_msc_list,
        "Time": [datetime.fromtimestamp(t/1000).strftime('%Y.%m.%d %H:%M:%S.%f')[:-3] for t in time_msc_list],
        "Bid": bids,
        "Ask": asks,
        "Spread": spreads,
        "BidVol": bid_vols,
        "AskVol": ask_vols,
        "Ping": pings
    })

    # Fájl írása (Helyfüggő)
    base_dir = os.path.dirname(os.path.abspath(__file__))
    target_dir = os.path.join(base_dir, "..", "data")
    os.makedirs(target_dir, exist_ok=True)
    full_path = os.path.abspath(os.path.join(target_dir, os.path.basename(filepath)))

    df.to_csv(full_path, index=False)
    print(f"✅ Mock adat generálva: {full_path} | Memória lábnyom: {df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")

    # Memória felszabadítás
    del df
    del time_msc_list, bids, asks, spreads, pings, bid_vols, ask_vols
    gc.collect()

    return full_path

if __name__ == "__main__":
    create_mock_tick_data()
