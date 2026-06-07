import re

with open("trade_entry_analyzer.py", "r", encoding="utf-8") as f:
    content = f.read()

# Fix the KeyError by using .get()
content = content.replace("entries = hybrid_df[(hybrid_df['Target'] == 0) | (hybrid_df['Target'] == 1)]",
                          "target_series = hybrid_df.get('Target', pd.Series([-1]*len(hybrid_df)))\n            entries = hybrid_df[(target_series == 0) | (target_series == 1)]")

with open("trade_entry_analyzer_fixed.py", "w", encoding="utf-8") as f:
    f.write(content)
