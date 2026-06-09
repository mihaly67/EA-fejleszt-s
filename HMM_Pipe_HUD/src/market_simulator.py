import time
import pandas as pd

class MarketSimulator:
    def __init__(self, s5_df, m1_df, m5_df):
        self.s5_df = s5_df
        self.m1_df = m1_df
        self.m5_df = m5_df
        # Create an iterator for the fastest timeframe (S5)
        self.s5_iterator = self.s5_df.iterrows()

    def fetch_next_tick(self):
        try:
            s5_time, s5_row = next(self.s5_iterator)

            # Floor S5 time to the nearest 1 minute
            m1_time_floored = s5_time.floor('1min')
            m1_row = None
            if m1_time_floored in self.m1_df.index:
                m1_row = self.m1_df.loc[m1_time_floored]

            # Floor S5 time to the nearest 5 minutes
            m5_time_floored = s5_time.floor('5min')
            m5_row = None
            if m5_time_floored in self.m5_df.index:
                m5_row = self.m5_df.loc[m5_time_floored]

            return {
                's5_time': s5_time,
                's5_data': s5_row,
                'm1_time': m1_time_floored,
                'm1_data': m1_row,
                'm5_time': m5_time_floored,
                'm5_data': m5_row
            }
        except StopIteration:
            return None

if __name__ == '__main__':
    from data_pipeline import load_and_resample
    csv_file = '/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_v1.10_20260408_025931.csv'
    s5, m1, m5 = load_and_resample(csv_file)
    sim = MarketSimulator(s5, m1, m5)

    print('Testing simulator for 10 ticks...')
    for i in range(10):
        tick = sim.fetch_next_tick()
        if tick:
            print(f"Tick {i+1}: S5={tick['s5_time']} | M1={tick['m1_time']} | M5={tick['m5_time']}")
        time.sleep(0.05)
