import random

# --- CONFIG ---
DATA_LEN = 1000
MICRO_DEPTH = 5
SEC_DEPTH = 30
LOOKBACK = 200

# --- MOCK DATA ---
highs = [100.0] * DATA_LEN
lows = [90.0] * DATA_LEN
closes = [95.0] * DATA_LEN

# Generate random walk
for i in range(1, DATA_LEN):
    delta = (random.random() - 0.5) * 2.0
    closes[i] = closes[i-1] + delta
    highs[i] = closes[i] + random.random()
    lows[i] = closes[i] - random.random()

# --- ALGORITHM REPLICATION ---

def calculate_zigzag(depth, length, h, l):
    zz_h = [0.0] * length
    zz_l = [0.0] * length

    # Simple highest/lowest scan logic (ignoring Deviation/Backstep for simplicity in this test)
    # We just want to see if the loops work.
    for i in range(depth, length):
        # High Check
        local_h = h[i]
        is_high = True
        for k in range(1, depth + 1):
            if h[i-k] > local_h:
                is_high = False; break
        if is_high: zz_h[i] = local_h

        # Low Check
        local_l = l[i]
        is_low = True
        for k in range(1, depth + 1):
            if l[i-k] < local_l:
                is_low = False; break
        if is_low: zz_l[i] = local_l

    return zz_h, zz_l

def calculate_pivots(zz_h, zz_l, length):
    r1 = [0.0] * length
    s1 = [0.0] * length
    p = [0.0] * length

    for i in range(length):
        # Lookback Logic
        search_limit = 200

        curr_r = 0.0
        # Find R1
        for k in range(i, max(-1, i - search_limit), -1):
            if zz_h[k] != 0:
                curr_r = zz_h[k]
                break

        curr_s = 0.0
        # Find S1
        for k in range(i, max(-1, i - search_limit), -1):
            if zz_l[k] != 0:
                curr_s = zz_l[k]
                break

        r1[i] = curr_r
        s1[i] = curr_s
        p[i] = (curr_r + curr_s + closes[i]) / 3.0

    return r1, s1, p

# --- RUN TEST ---
print("Running Pivot Simulation...")

# 1. Micro
print(f"Calculating Micro (Depth {MICRO_DEPTH})...")
m_zz_h, m_zz_l = calculate_zigzag(MICRO_DEPTH, DATA_LEN, highs, lows)
m_r1, m_s1, m_p = calculate_pivots(m_zz_h, m_zz_l, DATA_LEN)

# 2. Secondary
print(f"Calculating Secondary (Depth {SEC_DEPTH})...")
s_zz_h, s_zz_l = calculate_zigzag(SEC_DEPTH, DATA_LEN, highs, lows)
s_r1, s_s1, s_p = calculate_pivots(s_zz_h, s_zz_l, DATA_LEN)

# --- VERIFICATION ---
# Check last 10 bars
print("\n--- RESULTS (Last 10 Bars) ---")
print(f"{'Idx':<5} | {'Micro R1':<10} | {'Micro S1':<10} | {'Sec R1':<10} | {'Sec S1':<10}")
for i in range(DATA_LEN - 10, DATA_LEN):
    print(f"{i:<5} | {m_r1[i]:<10.2f} | {m_s1[i]:<10.2f} | {s_r1[i]:<10.2f} | {s_s1[i]:<10.2f}")

# Sanity Check
# Secondary levels should change LESS frequently than Micro levels
m_changes = 0
s_changes = 0
for i in range(1, DATA_LEN):
    if m_r1[i] != m_r1[i-1]: m_changes += 1
    if s_r1[i] != s_r1[i-1]: s_changes += 1

print(f"\nMicro Changes: {m_changes}")
print(f"Sec Changes:   {s_changes}")

if s_changes < m_changes and s_changes > 0:
    print("✅ SUCCESS: Secondary ZigZag is slower (more stable) than Micro.")
else:
    print("❌ FAILURE: Secondary Logic seems wrong (same speed or zero).")

if 0 in s_r1[DATA_LEN-50:]:
    print("⚠️ WARNING: Zeros detected in R1 buffer (Lookback too short or Depth too high for data?)")
