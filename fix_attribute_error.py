import re

with open("vaku3_online_hybrid_v9.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Look for the remnants of 'inp_chaos_lim'
# In get_reason
content = content.replace("chaos_lim = self.get_safe_float(self.inp_chaos_lim, 0.05)", "")

# In update_gui_charts
content = content.replace("chaos_lim = self.get_safe_float(self.inp_chaos_lim, 0.05)", "")

# Wait, the `update_gui_charts` doesn't have `mac_chaos_lim`? Let's check how the last script actually modified `update_gui_charts`.
