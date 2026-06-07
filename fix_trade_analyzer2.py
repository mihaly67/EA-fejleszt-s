import re

with open("trade_entry_analyzer_fixed.py", "r", encoding="utf-8") as f:
    content = f.read()

# Fix the column names for Target (it was Broker_Reaction_Target previously)
content = content.replace("hybrid_df.get('Target'", "hybrid_df.get('Broker_Reaction_Target'")
content = content.replace("row.get('Target', -1)", "row.get('Broker_Reaction_Target', -1)")

with open("trade_entry_analyzer_fixed2.py", "w", encoding="utf-8") as f:
    f.write(content)
