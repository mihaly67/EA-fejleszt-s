import re

with open("vaku3_dashboard_v9c.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Kijavítjuk az adatbeolvasási hibát (KeyError) és beépítjük a dinamikus számolást
# Korábban a kódban benne maradt a 'macro_er = float(row['Macro_ER'])', ami miatt összedőlt

broken_logic = """            row = self.stream.get_next_tick()
            unix_ms = float(row['TickMSC'])
            price = float(row['Price'])
            macro_er = float(row['Macro_ER'])
            risk = float(row.get('Theater_Risk_Pct', 0.0))
            decision = row.get('Hybrid_Decision', 'RED')
            
            # Valós idejű generálás a teszt miatt, mivel a nyers CSV-t töltjük be
            # Ide jönne a Python Engine (vaku3_online_hybrid) beágyazása
            
            # --- VALÓDI STATISZTIKAI KALKULÁTOR A GUI-BAN (Zajszűrt) ---"""


fixed_logic = """            row = self.stream.get_next_tick()
            unix_ms = float(row['TickMSC'])
            price = float(row['Price'])
            
            # --- VALÓDI STATISZTIKAI KALKULÁTOR A GUI-BAN (Zajszűrt) ---
            # Ha a CSV már tartalmazza az előre kiszámolt ML adatokat (pl. kiértékelt eval CSV):
            if 'Macro_ER' in row and 'Hybrid_Decision' in row:
                macro_er = float(row['Macro_ER'])
                risk = float(row.get('Theater_Risk_Pct', 0.0))
                decision = row['Hybrid_Decision']
            else:
                # HA NYERS CSV-T TÖLTÜNK BE (pl. a 2-napos arany), AKKOR VALÓS IDŐBEN SZÁMOLJUK:
"""

content = content.replace(broken_logic, fixed_logic)

with open("vaku3_dashboard_v9d.py", "w", encoding="utf-8") as f:
    f.write(content)

