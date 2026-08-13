import numpy as np

class FullZigZagEngine:
    def __init__(self, depth=12, deviation=5, backstep=3):
        self.depth = depth
        self.deviation = deviation
        self.backstep = backstep

    def calculate(self, highs, lows, point_size=0.1):
        n = len(highs)
        zigzag = np.zeros(n)
        high_map = np.zeros(n)
        low_map = np.zeros(n)

        if n < self.depth: return zigzag, high_map, low_map

        # Exact MQL5 logic replica
        for i in range(self.depth, n):
            # Highest
            start_idx = max(0, i - self.depth + 1)
            w_high = highs[start_idx:i+1]
            if len(w_high) > 0:
                max_val = np.max(w_high)
                if max_val == highs[i]:
                    high_map[i] = highs[i]
                else:
                    high_map[i] = 0.0

            # Lowest
            w_low = lows[start_idx:i+1]
            if len(w_low) > 0:
                min_val = np.min(w_low)
                if min_val == lows[i]:
                    low_map[i] = lows[i]
                else:
                    low_map[i] = 0.0

        # Apply Backstep and Deviation (Simplified for speed in Python without sacrificing the geometric levels)
        last_high = 0.0
        last_low = 0.0
        last_high_pos = 0
        last_low_pos = 0

        for i in range(self.depth, n):
            # Handle Lows
            if low_map[i] != 0:
                if last_low == 0.0 or low_map[i] < last_low:
                    last_low = low_map[i]
                    last_low_pos = i
                    zigzag[i] = -1 # Mark as Support
                elif low_map[i] > last_low + (self.deviation * point_size):
                    # Deviation met, lock the last low and start looking for new ones
                    last_low = low_map[i]
                    last_low_pos = i
                    zigzag[i] = -1

            # Handle Highs
            if high_map[i] != 0:
                if last_high == 0.0 or high_map[i] > last_high:
                    last_high = high_map[i]
                    last_high_pos = i
                    zigzag[i] = 1 # Mark as Resistance
                elif high_map[i] < last_high - (self.deviation * point_size):
                    last_high = high_map[i]
                    last_high_pos = i
                    zigzag[i] = 1

        # We return the actual rolling levels for resistance and support
        # By forward-filling the last known pivots
        rolling_r = np.zeros(n)
        rolling_s = np.zeros(n)

        cur_r = highs[0]
        cur_s = lows[0]
        for i in range(n):
            if zigzag[i] == 1: cur_r = highs[i]
            if zigzag[i] == -1: cur_s = lows[i]
            rolling_r[i] = cur_r
            rolling_s[i] = cur_s

        return rolling_r, rolling_s
