import re

with open("vaku3_dashboard_v6.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Beépítjük az új 'Aggressive Trend' logikát és a CSV indikátorok felolvasását

fake_logic = """        self.df = pd.DataFrame({
            'TickMSC': unix_time,
            'Price': price,
            'Macro_ER': macro_er,
            'Theater_Risk_Pct': risk,
            'Hybrid_Decision': decisions
        })"""

real_logic = """        self.df = pd.DataFrame({
            'TickMSC': unix_time,
            'Price': price,
            'Macro_ER': macro_er,
            'Theater_Risk_Pct': risk,
            'Hybrid_Decision': decisions,
            'Velocity': np.zeros(N),
            'Hybrid_MACD': np.zeros(N)
        })"""

content = content.replace(fake_logic, real_logic)

# Változtassuk meg a V9 nevet
content = content.replace("Valós Idejű Advisory Műszerfal V6 (Time-Based Engine)", "Valós Idejű Advisory Műszerfal V9 (HMM+CSV Indikátorok)")

# A GUI-n frissítjük a magyarázó szövegeket az agresszív skalpolás miatt
reason_old = """        if decision == 'GREEN': return "OK:\\nKiszámítható Makro Trend.\\nNincs Brókeri Manipuláció."
        if decision == 'YELLOW': return f"OK:\\nA Makro Trend Erős (ER={macro_er:.2f}), DE a HMM \\nvalószínűsít egy Whipsaw-t (Kockázat={risk:.1f}%).\\nVárj a belépéssel!"
        if decision == 'RED':
            if macro_er < 0.3: return f"OK (LÁTSZÓLAG BIZTONSÁGOS, DE TILTOTT):\\nA görbe laposnak tűnhet, de a Makro ER nagyon\\nalacsony ({macro_er:.2f}). A piac zajos (Oldalazás).\\nA robottal ilyenkor belépni orosz rulett."
            else: return f"OK (TÖKÉLETES VIHAR):\\nExtrém magas Brókeri Kockázat ({risk:.1f}%).\\nSpread tágítás vagy azonnali fordulat várható.\""""

reason_new = """        if decision == 'GREEN': return "OK:\\nKiszámítható Makro Trend VAGY Agresszív Kitörés.\\nMehet a Skalpolás!"
        if decision == 'YELLOW': return f"OK:\\nA Makro Trend Erős, DE a HMM \\nvalószínűsít egy Whipsaw-t (Kockázat={risk:.1f}%).\\nVárj a belépéssel!"
        if decision == 'RED':
            if macro_er < 0.15: return f"OK (LÁTSZÓLAG BIZTONSÁGOS, DE TILTOTT):\\nA görbe laposnak tűnhet, de a Makro ER nagyon\\nalacsony ({macro_er:.2f}). A piac zajos (Oldalazás).\\nA robottal ilyenkor belépni orosz rulett."
            else: return f"OK (TÖKÉLETES VIHAR):\\nExtrém magas Brókeri Kockázat ({risk:.1f}%).\\nSpread tágítás vagy azonnali fordulat várható.\""""

content = content.replace(reason_old, reason_new)

with open("vaku3_dashboard_v9.py", "w", encoding="utf-8") as f:
    f.write(content)
