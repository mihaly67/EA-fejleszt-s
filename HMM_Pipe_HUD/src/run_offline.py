import sys
from data_pipeline import load_and_resample
from market_simulator import MarketSimulator
from core_engine import HMMCoreEngine

def main():
    csv_file = '/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_v1.10_20260408_025931.csv'

    print("--- 1. FÁZIS: Adat-előkészítés (Data Pipeline) ---")
    s5_df, m1_df, m5_df = load_and_resample(csv_file)
    print(f"Előkészítve: {len(s5_df)} S5, {len(m1_df)} M1 és {len(m5_df)} M5 gyertya.\n")

    print("--- 2. FÁZIS: Offline Időgép (Market Simulator) ---")
    sim = MarketSimulator(s5_df, m1_df, m5_df)

    print("--- 3. FÁZIS: HMM Matematikai Motor (Core Engine) ---")
    engine = HMMCoreEngine()

    # Pre-warm the HMM engine lists directly so it can skip initialisation
    engine.window_s5 = [[row['LogReturn'], row['ATR_Proxy']] for row in s5_df.head(60).to_dict('records') if row['LogReturn'] != 0.0]
    engine.window_m1 = [[row['LogReturn'], row['ATR_Proxy']] for row in m1_df.head(100).to_dict('records') if row['LogReturn'] != 0.0]
    engine.window_m5 = [[row['LogReturn'], row['ATR_Proxy']] for row in m5_df.head(35).to_dict('records') if row['LogReturn'] != 0.0]

    print("\n=== Elemzés indítása valós S5 tickeken ===")
    sys.stdout.flush()
    # Pörgetés előre, hogy az ablakokkal szinkronban legyünk a CSV-ben
    for _ in range(16000):
        sim.fetch_next_tick()

    for i in range(150):
        tick = sim.fetch_next_tick()
        if not tick:
            print("Adatok vége.")
            break

        advice = engine.process_tick(tick['s5_data'], tick['m1_time'], tick['m1_data'], tick['m5_time'], tick['m5_data'])
        print(f"Tick {i+1} [{tick['s5_time']}]: {advice}")

    print("\nOffline Pipeline teszt sikeresen lefutott.")

if __name__ == '__main__':
    main()
