import re

with open("vaku3_hybrid_engine_fixed.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Lazítjuk a küszöböket (0.3 -> 0.15 a makro ER-re)
content = content.replace("macro_er_threshold=0.3", "macro_er_threshold=0.15")
content = content.replace("macro_er >= 0.3", "macro_er >= 0.15")
content = content.replace("macro_er < 0.3", "macro_er < 0.15")

# 2. Hozzáadjuk a 4. állapotot a szabályokhoz (Aggressive Trend)
# Ha a HMM Aggressive Trend-et jelez, az felülbírálhat egy sárga jelzést
# Ehhez módosítani kell a process_hybrid_matrix logikáját
hybrid_logic_old = """        conditions = [
            (hybrid_df['Macro_ER'] >= self.macro_er_threshold) & (hybrid_df.get('Theater_Risk_Pct', pd.Series([0]*len(hybrid_df))) < self.hmm_risk_threshold),
            (hybrid_df['Macro_ER'] >= self.macro_er_threshold) & (hybrid_df.get('Theater_Risk_Pct', pd.Series([0]*len(hybrid_df))) >= self.hmm_risk_threshold),
            (hybrid_df['Macro_ER'] < self.macro_er_threshold)
        ]

        choices = ['GREEN', 'YELLOW', 'RED']"""

hybrid_logic_new = """
        risk_series = hybrid_df.get('Theater_Risk_Pct', pd.Series([0]*len(hybrid_df)))
        state_series = hybrid_df.get('HMM_State_Name', pd.Series(['Unknown']*len(hybrid_df)))

        # Új, megengedőbb szabályok a hajnali skalpolások miatt:
        # 1. GREEN: Ha a Makro jó, a Kockázat alacsony VAGY ha a HMM "Aggressive_Trend"-et detektál! (a sebesség felülírja a kockázatot bizonyos fokig)
        # 2. YELLOW: Ha a Makro jó, de a Kockázat magas, és nem vagyunk Agresszív Trendben
        # 3. RED: Ha a Makro rossz (zajos, lapos), KIVÉVE, ha van egy hirtelen Agresszív Trend

        conditions = [
            (state_series == 'Aggressive_Trend') | ((hybrid_df['Macro_ER'] >= self.macro_er_threshold) & (risk_series < self.hmm_risk_threshold)),
            (hybrid_df['Macro_ER'] >= self.macro_er_threshold) & (risk_series >= self.hmm_risk_threshold),
            (hybrid_df['Macro_ER'] < self.macro_er_threshold)
        ]

        choices = ['GREEN', 'YELLOW', 'RED']"""

content = content.replace(hybrid_logic_old, hybrid_logic_new)

with open("vaku3_hybrid_engine_VPS_V9.py", "w", encoding="utf-8") as f:
    f.write(content)
