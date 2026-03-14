with open("MQL5/Indicators/Jules/Merkava_Offline_Miner_v1_00.mq5", "r") as f:
    content = f.read()

# Replace variables in the initialization call
vars_to_replace = [
    "h_fast", "h_slow", "h_bb_per", "h_bb_dev", "h_bb_meth",
    "h_kelt_per", "h_kelt_dev", "h_kelt_atr", "h_kelt_meth",
    "h_macd_scale", "h_shift", "h_scale", "h_auto", "h_lookback", "h_divisor",
    "_f_fixed", "_f_min", "_f_max", "_f_mfi", "_f_vroc", "_f_vroc_p",
    "_f_approx", "_f_smooth", "_f_norm", "_f_scale_f", "_f_vis"
]

for var in vars_to_replace:
    content = content.replace(f" {var},", f" {var}_inp,")
    content = content.replace(f" {var} ", f" {var}_inp ")

with open("MQL5/Indicators/Jules/Merkava_Offline_Miner_v1_00.mq5", "w") as f:
    f.write(content)
