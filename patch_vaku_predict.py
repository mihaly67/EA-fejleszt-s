import re

with open("vaku3_offline_validator_local.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Beépítjük a predikciós logikát a Vaku3OfflineValidator osztályba
prediction_method = """

    def predict_future_risk(self, log_er, elasticity, z_tick_density):
        \"\"\"
        A Viterbi/Transmat logika: Megmondja, mekkora az esélye a 'Színház' állapotnak a következő pillanatban.
        \"\"\"
        if not self.is_fitted:
            return 0.0

        obs = np.array([[log_er, elasticity, z_tick_density]])
        obs_scaled = self.scaler.transform(obs)
        
        # 1. Jelenlegi állapot valószínűség (Posterior)
        # Ez egy array (1, n_components) pl: [0.1, 0.8, 0.1]
        posterior_probs = self.model.predict_proba(obs_scaled)[-1]
        
        # 2. Átmeneti mátrix (Transition Matrix) 
        # (n_components, n_components)
        trans_mat = self.model.transmat_
        
        # 3. Jövőbeli valószínűség kiszámítása = Posterior dot TransMat
        future_probs = np.dot(posterior_probs, trans_mat)
        
        # 4. Kiszedjük a 'Színház' (Manipuláció) jövőbeli rizikóját
        theater_id = self.state_map.get("Theater", -1)
        if theater_id != -1:
            return future_probs[theater_id]
        return 0.0
"""

# Hozzáadjuk a metódust a predict_state után
content = content.replace(
    '        hidden_state_idx = self.model.predict(obs_scaled)[0]\n        \n        for state_name, state_id in self.state_map.items():\n            if state_id == hidden_state_idx:\n                return state_name, hidden_state_idx\n        return "Unknown", hidden_state_idx',
    '        hidden_state_idx = self.model.predict(obs_scaled)[0]\n        \n        for state_name, state_id in self.state_map.items():\n            if state_id == hidden_state_idx:\n                return state_name, hidden_state_idx\n        return "Unknown", hidden_state_idx' + prediction_method
)

# 2. A run_validator()-ban futtatjuk és mérjük a Predikciót is
run_old = """                state_name, state_id = validator.predict_state(
                    row['Log-ER_Scale_Cor'],
                    row['Elasticity_Ratio'],
                    row['Tick_Density_Z']
                )
                df.at[idx, 'HMM_State_ID'] = state_id
                df.at[idx, 'HMM_State_Name'] = state_name"""

run_new = """                state_name, state_id = validator.predict_state(
                    row['Log-ER_Scale_Cor'],
                    row['Elasticity_Ratio'],
                    row['Tick_Density_Z']
                )
                future_risk = validator.predict_future_risk(
                    row['Log-ER_Scale_Cor'],
                    row['Elasticity_Ratio'],
                    row['Tick_Density_Z']
                )
                
                df.at[idx, 'HMM_State_ID'] = state_id
                df.at[idx, 'HMM_State_Name'] = state_name
                df.at[idx, 'Theater_Risk_Pct'] = future_risk * 100.0"""

content = content.replace(run_old, run_new)

# 3. Kiegészítjük a Riportot a Jövőkutatással
report_old = """    print("--- SMOKING GUN BIZONYÍTÉK (Offline Causal Validation) ---")
    print(f"Összes megjelölt Brókeri Reakció (Target=1): {total_target_1} db")"""

report_new = """    print("--- SMOKING GUN BIZONYÍTÉK (Offline Causal Validation) ---")
    print(f"Összes megjelölt Brókeri Reakció (Target=1): {total_target_1} db")
    
    # Kiszámoljuk hányszor jelezte a jövőkutató, hogy nagy a baj (Risk > 40%) még a Target=1 PONTOS bekövetkezése ELŐTT 3 tickkel
    early_warnings = 0
    if total_target_1 > 0:
        target_indices = df[df['Target'] == 1].index
        for t_idx in target_indices:
            # Megnézzük a megelőző 3 tick 'Theater_Risk_Pct' értékét
            start_idx = max(0, t_idx - 3)
            if df.loc[start_idx:t_idx-1, 'Theater_Risk_Pct'].max() > 40.0:
                early_warnings += 1
        
        print(f"  -> PREDIKTÍV ELŐREJELZÉS (Risk > 40% a trükk előtt 3 ticken belül): {early_warnings} db ({early_warnings/total_target_1*100:.1f}%) 🔮")
"""
content = content.replace(report_old, report_new)

with open("vaku3_offline_validator_local.py", "w", encoding="utf-8") as f:
    f.write(content)
