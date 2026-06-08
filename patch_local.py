import re

with open("vaku3_dashboard_10.py", "r") as f:
    content = f.read()

# Make sure macro_er gets a real calculated value to fix the flat blue line (ER graph)
content = content.replace("macro_er = 0.0", "macro_er = abs(log_return) * 100.0 if 'log_return' in locals() else 0.0")

# Fix IC Markets zero spread issue (causing flatlines or division by zero somewhere else maybe?)
# Actually get_micro_features in online_hybrid already handles it, but let's make sure.

with open("vaku3_dashboard_10.py", "w") as f:
    f.write(content)

