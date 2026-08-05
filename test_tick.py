with open("Micro_LGBM/src/mt5_live_copilot.py", "r") as f:
    content = f.read()
if "tick_vol = 1.0" in content:
    print("Tick Volume is indeed fixed in the source file.")
