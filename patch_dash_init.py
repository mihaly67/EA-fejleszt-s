with open("vaku3_online_hybrid.py", "r") as f:
    content = f.read()

content = content.replace("        self.is_hmm_trained = False", "        self.is_hmm_trained = False\n        self.macro_window_minutes = macro_window_minutes\n        self.macro_times = []\n        self.macro_prices = []")

with open("vaku3_online_hybrid.py", "w") as f:
    f.write(content)

