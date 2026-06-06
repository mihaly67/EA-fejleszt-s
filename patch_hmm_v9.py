import re

with open("vaku3_offline_validator_local_final.py", "r", encoding="utf-8") as f:
    content = f.read()

# Kibővítjük a HMM dimenzióit (n_components=4, és a feature space-t)
# N_components növelés, hogy a HMM finomabb állapotokat tudjon szétválasztani
content = content.replace('self.model = hmm.GaussianHMM(n_components=3, covariance_type="full", n_iter=100, random_state=42)',
                          'self.model = hmm.GaussianHMM(n_components=4, covariance_type="full", n_iter=100, random_state=42)')

# Átnevezzük az állapotokat, mivel most már 4 van
content = content.replace('self.state_map = {"Quiet": 0, "Concrete": 1, "Theater": 2}',
                          'self.state_map = {"Quiet": 0, "Concrete": 1, "Theater": 2, "Aggressive_Trend": 3}')

# Semantic Mapping rész frissítése, most 4 állapotra
mapping_old = """        # Megkeressük a legkisebb ER-t és legnagyobb spreadet -> Színház (Z-score alapján log_er a legkisebb negatív vagy legnagyobb spread)
        # mivel a scaler miatt ezek Z-score-ok (ahol a negatív ER azt jelenti, hogy nagyon nem hatékony/zajos)
        # Ez egy egyszerű heurisztika
        log_ers = means[:, er_idx]
        spreads = means[:, spread_idx]
        
        theater_idx = np.argmin(log_ers) # A leghatékonyatlanabb
        concrete_idx = np.argmax(log_ers) # A leghatékonyabb
        quiet_idx = [i for i in range(3) if i not in [theater_idx, concrete_idx]][0]
        
        self.state_map = {"Quiet": quiet_idx, "Concrete": concrete_idx, "Theater": theater_idx}"""

mapping_new = """        # 4 ÁLLAPOTOS SEMANTIC MAPPING (Az új Momentum indikátorok bevonásával)
        log_ers = means[:, 0]
        spreads = means[:, 1]
        velocities = means[:, 3] # A 4. dimenzió a Velocity (sebesség) lesz
        
        # A manipuláció (Theater) a legzajosabb (legkisebb ER) és gyakran nagy spread
        theater_idx = np.argmin(log_ers)
        
        # A többi 3 állapot közül az Aggressive Trend az, ahol a leggyorsabb az árfolyam (Max Velocity)
        remaining = [i for i in range(4) if i != theater_idx]
        aggressive_idx = remaining[np.argmax([abs(velocities[i]) for i in remaining])]
        
        # A maradék kettő közül a Concrete a hatékonyabb (Nagyobb ER), a Quiet a zajosabb/laposabb
        remaining = [i for i in remaining if i != aggressive_idx]
        if log_ers[remaining[0]] > log_ers[remaining[1]]:
            concrete_idx = remaining[0]
            quiet_idx = remaining[1]
        else:
            concrete_idx = remaining[1]
            quiet_idx = remaining[0]
            
        self.state_map = {"Quiet": quiet_idx, "Concrete": concrete_idx, "Theater": theater_idx, "Aggressive_Trend": aggressive_idx}"""

content = content.replace(mapping_old, mapping_new)

# A predict_state módosítása (Bemenet kibővítése)
predict_old = """    def predict_state(self, log_er, elasticity, z_tick_density):
        \"\"\"Visszaadja a pillanatnyi állapot nevét és az azonosítóját.\"\"\"
        if not self.is_fitted:
            return "Unknown", -1

        obs = np.array([[log_er, elasticity, z_tick_density]])"""

predict_new = """    def predict_state(self, log_er, elasticity, z_tick_density, velocity=0.0, macd=0.0):
        \"\"\"Visszaadja a pillanatnyi állapot nevét és az azonosítóját.\"\"\"
        if not self.is_fitted:
            return "Unknown", -1

        obs = np.array([[log_er, elasticity, z_tick_density, velocity, macd]])"""

content = content.replace(predict_old, predict_new)

predict_risk_old = """    def predict_future_risk(self, log_er, elasticity, z_tick_density):
        \"\"\"
        A Viterbi/Transmat logika: Megmondja, mekkora az esélye a 'Színház' állapotnak a következő pillanatban.
        \"\"\"
        if not self.is_fitted:
            return 0.0

        obs = np.array([[log_er, elasticity, z_tick_density]])"""

predict_risk_new = """    def predict_future_risk(self, log_er, elasticity, z_tick_density, velocity=0.0, macd=0.0):
        \"\"\"
        A Viterbi/Transmat logika: Megmondja, mekkora az esélye a 'Színház' állapotnak a következő pillanatban.
        \"\"\"
        if not self.is_fitted:
            return 0.0

        obs = np.array([[log_er, elasticity, z_tick_density, velocity, macd]])"""

content = content.replace(predict_risk_old, predict_risk_new)

# A feature space összerakása futáskor a datasetből (run_validator)
run_validator_old = """                state_name, state_id = validator.predict_state(
                    row['Log-ER_Scale_Cor'],
                    row['Elasticity_Ratio'],
                    row['Tick_Density_Z']
                )
                future_risk = validator.predict_future_risk(
                    row['Log-ER_Scale_Cor'],
                    row['Elasticity_Ratio'],
                    row['Tick_Density_Z']
                )"""

run_validator_new = """                # Biztosítás, ha nincsenek az MT5 indikátorok a csv-ben
                vel = row.get('Velocity', 0.0)
                macd = row.get('Hybrid_MACD', 0.0)
                
                state_name, state_id = validator.predict_state(
                    row['Log-ER_Scale_Cor'],
                    row['Elasticity_Ratio'],
                    row['Tick_Density_Z'],
                    vel,
                    macd
                )
                future_risk = validator.predict_future_risk(
                    row['Log-ER_Scale_Cor'],
                    row['Elasticity_Ratio'],
                    row['Tick_Density_Z'],
                    vel,
                    macd
                )"""

content = content.replace(run_validator_old, run_validator_new)

# A Data Builder módosítása
feature_extract_old = """                # Az Orthogonal Observation Space: [Log-ER, Spread Elasticity, Z-Tick Density]
                features.append([log_er, elasticity, z_tick_density])
            else:
                # Bemelegedési fázis (Warm-up)
                features.append([0.0, 1.0, 0.0])"""

feature_extract_new = """                # Bővített Observation Space: [Log-ER, Spread Elasticity, Z-Tick Density, Velocity, MACD]
                vel = row.get('Velocity', 0.0)
                macd = row.get('Hybrid_MACD', 0.0)
                features.append([log_er, elasticity, z_tick_density, vel, macd])
            else:
                # Bemelegedési fázis (Warm-up)
                features.append([0.0, 1.0, 0.0, 0.0, 0.0])"""

content = content.replace(feature_extract_old, feature_extract_new)

with open("vaku3_offline_validator_VPS_V9.py", "w", encoding="utf-8") as f:
    f.write(content)
