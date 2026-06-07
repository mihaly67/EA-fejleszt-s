import re

with open("vaku3_dashboard_10.py", "r") as f:
    content = f.read()

# Eltávolítjuk a macro_er hivatkozást a GUI-ból, mivel az update_macro_context a V9-ből való, most az online hybrid motor máshogy számolja az egészet.
content = content.replace("macro_er = self.engine.update_macro_context(unix_ms, price)", "macro_er = 0.0")

with open("vaku3_dashboard_10.py", "w") as f:
    f.write(content)
