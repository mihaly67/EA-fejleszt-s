import re

file_path = "Micro_LGBM/src/mt5_live_copilot.py"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

find_print = """                                    # Send back to EA
                                    msg = f"PRED|{sig}|{pl:.4f}|{ps:.4f}|{pn:.4f}\\n"
                                    try:
                                        client.sendall(msg.encode('utf-8'))"""

repl_print = """                                    # Send back to EA
                                    msg = f"PRED|{sig}|{pl:.4f}|{ps:.4f}|{pn:.4f}\\n"
                                    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 🔥 DOLLAR BAR PREDICTION GENERATED! {msg}")
                                    try:
                                        client.sendall(msg.encode('utf-8'))"""

text = text.replace(find_print, repl_print)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)
