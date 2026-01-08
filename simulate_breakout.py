import random

# --- CONFIG ---
DATA_LEN = 5000
SCAN_LIMIT = 2000

# --- MOCK DATA ---
# Create a "Wave" pattern: Up, Down, Up (higher), Down (lower), Up (Breakout)
highs = [100.0] * DATA_LEN
lows = [90.0] * DATA_LEN
closes = [95.0] * DATA_LEN
zz_buffer = [0.0] * DATA_LEN

# Define pivots manually to test search
# Index 1000: High at 110
highs[1000] = 110.0; zz_buffer[1000] = 110.0
# Index 2000: High at 120 (Target for Breakout)
highs[2000] = 120.0; zz_buffer[2000] = 120.0
# Index 3000: High at 115 (Current Local High)
highs[3000] = 115.0; zz_buffer[3000] = 115.0
# Index 4000: Price breaks 115, goes to 116. Should find 120.

# --- ALGORITHM REPLICATION ---

def find_historic_resistance(buffer, h_arr, start_idx, price):
    limit = max(0, start_idx - SCAN_LIMIT)
    for k in range(start_idx, limit, -1):
        val = buffer[k]
        if val != 0:
            if abs(val - h_arr[k]) < 0.0001: # Is High
                if val > price:
                    return val, k
    return -1.0, -1

# --- RUN TEST ---
print("Running Breakout Simulation...")

current_idx = 4000
current_price = 116.0 # Breakout above 115
print(f"Current Price at idx {current_idx}: {current_price}")
print("Searching for next resistance...")

res_val, res_idx = find_historic_resistance(zz_buffer, highs, current_idx, current_price)

print(f"Result: {res_val} at index {res_idx}")

if res_val == 120.0 and res_idx == 2000:
    print("✅ SUCCESS: Found historical resistance at 120.0 (Index 2000).")
    print("   Note: It correctly skipped the local high at 115 (Index 3000) because 115 < 116.")
else:
    print(f"❌ FAILURE: Expected 120.0, got {res_val}")

# Test Support Breakdown
print("\nTesting Support Breakdown...")
lows[1500] = 80.0; zz_buffer[1500] = 80.0 # Deep low
lows[3500] = 90.0; zz_buffer[3500] = 90.0 # Local low

breakdown_price = 85.0 # Below 90, looking for 80
def find_historic_support(buffer, l_arr, start_idx, price):
    limit = max(0, start_idx - SCAN_LIMIT)
    for k in range(start_idx, limit, -1):
        val = buffer[k]
        if val != 0:
            if abs(val - l_arr[k]) < 0.0001: # Is Low
                if val < price:
                    return val, k
    return -1.0, -1

sup_val, sup_idx = find_historic_support(zz_buffer, lows, 4000, breakdown_price)
print(f"Result: {sup_val} at index {sup_idx}")

if sup_val == 80.0 and sup_idx == 1500:
     print("✅ SUCCESS: Found historical support at 80.0.")
else:
     print(f"❌ FAILURE: Expected 80.0, got {sup_val}")
