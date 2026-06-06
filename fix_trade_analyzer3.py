import re

with open("trade_entry_analyzer_fixed2.py", "r", encoding="utf-8") as f:
    content = f.read()

# Modify to actually check only REAL entries, not just Target rows 
# We need to look for actual trades, usually marked with a target or action
content = content.replace("entries = hybrid_df[(target_series == 0) | (target_series == 1)]", 
                          "target_1_entries = hybrid_df[target_series == 1]\n            target_0_entries = hybrid_df[target_series == 0]\n            entries = pd.concat([target_1_entries.head(50), target_0_entries.head(50)])")

with open("trade_entry_analyzer_fixed3.py", "w", encoding="utf-8") as f:
    f.write(content)
