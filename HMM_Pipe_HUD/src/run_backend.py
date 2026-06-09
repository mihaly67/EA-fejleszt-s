import time
import json
import os
from data_pipeline import load_and_resample
from market_simulator import MarketSimulator
from core_engine import HMMCoreEngine

def main():
    print("Backend indítása...")
    csv_file = '/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_v1.10_20260408_025931.csv'
    if not os.path.exists(csv_file):
        csv_file = 'data/Merkava_XAUUSD_v1.10_20260408_025931.csv'

    m1_df, m5_df, m15_df = load_and_resample(csv_file)
    sim = MarketSimulator(m1_df, m5_df, m15_df)
    engine = HMMCoreEngine()

    # Pre-warm (gyorsított inicializálás)
    m15_list = m15_df.head(35).to_dict('records')
    m5_list = m5_df.head(100).to_dict('records')
    m1_list = m1_df.head(60).to_dict('records')

    for row in m15_list: engine.process_tick(None, None, None, 'dummy', row)
    for row in m5_list: engine.process_tick(None, 'dummy', row, None, None)
    for row in m1_list: engine.process_tick(row, None, None, None, None)

    # Keresünk egy biztos pontot
    for _ in range(300): sim.fetch_next_tick()

    print("Backend készen áll, elindul a tick stream...")

    visible_window = 100
    history_data = []

    while True:
        tick = sim.fetch_next_tick()
        if not tick:
            print("Nincs több tick az időgépben.")
            break

        m1_data = tick['m1_data']
        advice = engine.process_tick(m1_data, tick['m5_time'], tick['m5_data'], tick['m15_time'], tick['m15_data'])

        current_state = 0
        if 'LONG' in advice or 'VÉTEL' in advice: current_state = 1
        elif 'SHORT' in advice or 'ELADÁS' in advice: current_state = -1

        tick_info = {
            'time': str(tick['m1_time']),
            'open': float(m1_data['open']),
            'high': float(m1_data['high']),
            'low': float(m1_data['low']),
            'close': float(m1_data['close']),
            'advice': advice,
            'state': current_state
        }

        history_data.append(tick_info)
        if len(history_data) > visible_window:
            history_data.pop(0)

        # JSON mentése
        with open('/tmp/hmm_latest_tick.json', 'w') as f:
            json.dump(tick_info, f)

        with open('/tmp/hmm_history.json', 'w') as f:
            json.dump(history_data, f)

        time.sleep(1.0) # Ez a háttér sebessége, ami hajtja a "piacot"

if __name__ == '__main__':
    main()
