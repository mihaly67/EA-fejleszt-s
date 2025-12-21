import math
import numpy as np

# --- MQL5 Logic Replica (FIXED) ---

def UpdateKalman(i, price, period, gain, lowpass_arr, delta_arr, output_arr):
    # Constants - FIXED FORMULA
    # Old: a = math.exp(-math.pi / period) -> Inverted logic
    # New: a = 2.0 / (period + 1.0) -> Standard EMA logic (Higher period = Lower alpha = Slower)

    a = 2.0 / (period + 1.0)
    b = 1.0 - a

    if i == 0:
        lowpass_arr[i] = price
        delta_arr[i] = 0.0
        output_arr[i] = price
        return

    # 1. Lowpass
    lowpass_arr[i] = b * lowpass_arr[i-1] + a * price

    # 2. Detrend
    detrend = price - lowpass_arr[i]

    # 3. Delta
    delta_arr[i] = b * delta_arr[i-1] + a * detrend

    # 4. Output
    output_arr[i] = lowpass_arr[i] + delta_arr[i] * gain

def tanh_norm(val, std, sens=1.0):
    if std == 0: return 0.0
    return 100.0 * math.tanh(val / (std * sens))

def simulate_trend():
    print("--- SIMULATION: UPTREND (10 -> 20) with FIX ---")
    length = 20
    prices = [10.0 + i for i in range(length)] # 10, 11, ... 29

    # Buffers
    k_fast_lp = [0.0]*length; k_fast_d = [0.0]*length; k_fast_out = [0.0]*length
    k_slow_lp = [0.0]*length; k_slow_d = [0.0]*length; k_slow_out = [0.0]*length
    raw_macd = [0.0]*length
    k_sig_lp = [0.0]*length; k_sig_d = [0.0]*length; k_sig_out = [0.0]*length
    macd_norm = [0.0]*length; sig_norm = [0.0]*length; hist = [0.0]*length

    # Params
    Fast = 5
    Slow = 13
    Sig = 6
    Gain = 1.0

    for i in range(length):
        p = prices[i]
        UpdateKalman(i, p, Fast, Gain, k_fast_lp, k_fast_d, k_fast_out)
        UpdateKalman(i, p, Slow, Gain, k_slow_lp, k_slow_d, k_slow_out)
        raw_macd[i] = k_fast_out[i] - k_slow_out[i]
        UpdateKalman(i, raw_macd[i], Sig, Gain, k_sig_lp, k_sig_d, k_sig_out)

        # Norm
        std = 1.0
        macd_norm[i] = tanh_norm(raw_macd[i], std)
        sig_norm[i] = tanh_norm(k_sig_out[i], std)
        hist[i] = macd_norm[i] - sig_norm[i]

        print(f"Bar {i}: Price={p:.1f} | Fast={k_fast_out[i]:.2f} Slow={k_slow_out[i]:.2f} | MACD={raw_macd[i]:.2f} | Hist={hist[i]:.2f}")

    print("\n--- CHECK ---")
    if hist[-1] > 0 and k_fast_out[-1] > k_slow_out[-1]:
        print("✅ UPTREND -> Positive Histogram. Fast > Slow. FIX CONFIRMED.")
    else:
        print("❌ UPTREND -> Negative Histogram. FIX FAILED.")

if __name__ == "__main__":
    simulate_trend()
