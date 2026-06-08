import re

with open("vaku3_dashboard_10.py", "r") as f:
    content = f.read()

# Make sure macro_er gets the correctly scaled value, without multiplying by 100 twice!
content = content.replace("self.macro_data[-1] = macro_er * 100", "self.macro_data[-1] = macro_er")
# Move it down so it correctly evaluates to the LATEST log_return that was calculated on THIS tick (not the previous frame's locals hack)
old_features = """            macro_er = abs(log_return) * 100.0 if 'log_return' in locals() else 0.0

            # Features & Training
            log_return, avg_spread, tick_density = self.engine.get_micro_features()"""

new_features = """            # Features & Training
            log_return, avg_spread, tick_density = self.engine.get_micro_features()
            macro_er = abs(log_return) * 100.0"""

content = content.replace(old_features, new_features)

with open("vaku3_dashboard_10.py", "w") as f:
    f.write(content)
