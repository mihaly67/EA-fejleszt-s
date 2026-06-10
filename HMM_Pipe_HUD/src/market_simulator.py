import time
import pandas as pd

class MarketSimulator:
    def __init__(self, m1_df, m5_df, m15_df):
        self.m1_df = m1_df
        self.m5_df = m5_df
        self.m15_df = m15_df
        self.m1_iterator = self.m1_df.iterrows()

    def fetch_next_tick(self):
        try:
            m1_time, m1_row = next(self.m1_iterator)
        except StopIteration:
            self.m1_iterator = self.m1_df.iterrows()
            m1_time, m1_row = next(self.m1_iterator)

        m5_time_floored = m1_time.floor('5min')
        m5_row = None
        if m5_time_floored in self.m5_df.index:
            m5_row = self.m5_df.loc[m5_time_floored]

        m15_time_floored = m1_time.floor('15min')
        m15_row = None
        if m15_time_floored in self.m15_df.index:
            m15_row = self.m15_df.loc[m15_time_floored]

        return {
            'm1_time': m1_time,
            'm1_data': m1_row,
            'm5_time': m5_time_floored,
            'm5_data': m5_row,
            'm15_time': m15_time_floored,
            'm15_data': m15_row
        }
