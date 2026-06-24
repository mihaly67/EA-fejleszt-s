import re

with open("vaku3_online_hybrid.py", "r", encoding="utf-8") as f:
    content = f.read()

# Make sure to catch exceptions so it prints something
content = content.replace("def run_stream(self, file_path):", "def run_stream(self, file_path):\n        try:")
content = content.replace("logger.info(f\"📊 EA Döntések: 🟢 ZÖLD: {decisions['GREEN']:,} | 🟡 SÁRGA: {decisions['YELLOW']:,} | 🔴 PIROS: {decisions['RED']:,}\")", "logger.info(f\"📊 EA Döntések: 🟢 ZÖLD: {decisions['GREEN']:,} | 🟡 SÁRGA: {decisions['YELLOW']:,} | 🔴 PIROS: {decisions['RED']:,}\")\n        except Exception as e:\n            logger.error(f\"Error: {e}\")")

with open("vaku3_online_hybrid_2.py", "w", encoding="utf-8") as f:
    f.write(content)

