import re

with open("vaku3_dashboard_v7.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Beépítjük a valódi O(1) ER és Risk számolást a zajos np.random helyett!

fake_logic = """            # Fake logic a CSV-hez:
            macro_er = np.random.uniform(0.1, 0.5) 
            risk = np.random.uniform(0, 30)
            decision = 'RED' if macro_er < 0.3 else ('YELLOW' if risk >= 20 else 'GREEN')"""

real_logic = """            # --- VALÓDI STATISZTIKAI KALKULÁTOR A GUI-BAN (Zajszűrt) ---
            # Makro ER (Kaufman) a történeti pufferből
            if len(self.history_prices) > 100:
                net_move = abs(self.history_prices[-1] - self.history_prices[0])
                gross_move = sum(abs(np.diff(self.history_prices[-100:])))
                macro_er = net_move / gross_move if gross_move > 0 else 0.0
            else:
                macro_er = 0.0
                
            # HMM Kockázat (Fake helyett most egy simított volatilitás indexet használunk vizuális helyettesítőként, 
            # ami nem "zajos", hanem ténylegesen a piac ugrásait követi, amíg a valódi ONNX be nem kerül)
            if len(self.history_prices) > 10:
                recent_volatility = np.std(self.history_prices[-10:])
                risk = min(100.0, recent_volatility * 100000) # Skálázás vizualizációhoz
            else:
                risk = 0.0
                
            # Exponenciális Mozgóátlag (EMA) a vizuális simításhoz (Hogy ne legyen "csupa zavar")
            alpha_er = 0.05  # Erős simítás az ER-en
            alpha_risk = 0.1 # Simítás a rizikón
            
            if self.ptr == 0:
                self.smoothed_er = macro_er
                self.smoothed_risk = risk
            else:
                self.smoothed_er = (alpha_er * macro_er) + ((1 - alpha_er) * self.smoothed_er)
                self.smoothed_risk = (alpha_risk * risk) + ((1 - alpha_risk) * self.smoothed_risk)
                
            macro_er = self.smoothed_er
            risk = self.smoothed_risk
            
            decision = 'RED' if macro_er < 0.3 else ('YELLOW' if risk >= 20 else 'GREEN')"""

content = content.replace(fake_logic, real_logic)

# Inicializáljuk a simító változókat az init-ben
init_old = """        self.playback_speed_multiplier = 1.0 
        self.is_paused = False"""

init_new = """        self.playback_speed_multiplier = 1.0 
        self.is_paused = False
        
        self.smoothed_er = 0.0
        self.smoothed_risk = 0.0"""

content = content.replace(init_old, init_new)

# Átnevezzük V8-ra
content = content.replace("Műszerfal V7 - ÉLŐ CSV SZIMULÁCIÓ", "Műszerfal V8 - ZAJMENTESÍTETT (Smoothed) ÉLŐ SZIMULÁCIÓ")

with open("vaku3_dashboard_v8.py", "w", encoding="utf-8") as f:
    f.write(content)
