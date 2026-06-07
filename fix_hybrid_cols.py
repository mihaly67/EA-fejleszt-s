import re

with open("vaku3_hybrid_engine.py", "r", encoding="utf-8") as f:
    content = f.read()

# Fix the column references to match what's actually in the CSV and fallback if missing
content = content.replace("hybrid_df['Theater_Risk_Pct'] < self.hmm_risk_threshold",
                          "hybrid_df.get('Theater_Risk_Pct', pd.Series([0]*len(hybrid_df))) < self.hmm_risk_threshold")
content = content.replace("hybrid_df['Theater_Risk_Pct'] >= self.hmm_risk_threshold",
                          "hybrid_df.get('Theater_Risk_Pct', pd.Series([0]*len(hybrid_df))) >= self.hmm_risk_threshold")

with open("vaku3_hybrid_engine_fixed.py", "w", encoding="utf-8") as f:
    f.write(content)
