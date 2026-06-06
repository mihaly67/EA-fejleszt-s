import re

with open("vaku3_offline_validator_VPS.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. StandardScaler importálása
if "from sklearn.preprocessing import StandardScaler" not in content:
    content = content.replace("import hmmlearn.hmm as hmm", "import hmmlearn.hmm as hmm\nfrom sklearn.preprocessing import StandardScaler")

# 2. Inicializáljuk a Scalert az init-ben
if "self.scaler = None" not in content:
    content = content.replace("self.is_fitted = False", "self.is_fitted = False\n        self.scaler = StandardScaler()")

# 3. A fit_and_map_states módosítása
fit_old = """    def fit_and_map_states(self):
        \"\"\"HMM betanítása és a Semantic Mapping ('Ördögűzés') elvégzése a Gemini alapján.\"\"\"
        if len(self.observation_space) < 100:
            logger.warning("Nincs elég adat a HMM betanításához!")
            return

        logger.info("Vaku 3.0 (GaussianHMM) betanítása az Ortogonális téren (Covar=Diag)...")
        self.model.fit(self.observation_space)
        self.is_fitted = True

        # --- SEMANTIC MAPPING (Az Öntanuló 'Színház' felismerés javított standardizálása) ---
        # A model.means_ tartalmazza a 3 rejtett állapot (0,1,2) 3D középértékeit:
        # Oszlopok: 0=Log-ER (negatív értékek), 1=Spread_Elasticity (~1.0), 2=Tick_Density (0 körüli Z-score)
        means = self.model.means_"""

fit_new = """    def fit_and_map_states(self):
        \"\"\"HMM betanítása és a Semantic Mapping ('Ördögűzés') elvégzése a Gemini alapján.\"\"\"
        if len(self.observation_space) < 100:
            logger.warning("Nincs elég adat a HMM betanításához!")
            return

        logger.info("Vaku 3.0 (GaussianHMM) betanítása az Ortogonális téren (Standardizálva, Covar=Diag)...")

        # [ÚJÍTÁS: STANDARD SCALER ALKALMAZÁSA]
        # Mivel a LogER (-15.0), a Spread (1.2) és a Tick Density eltérő skálán mozog, a GaussianHMM centroidjai
        # aránytalanul eltolódnak a LogER irányába. StandardScaler használatával minden dimenzió azonos súlyt kap.
        self.observation_space = self.scaler.fit_transform(self.observation_space)

        self.model.fit(self.observation_space)
        self.is_fitted = True

        # --- SEMANTIC MAPPING (Az Öntanuló 'Színház' felismerés javított standardizálása) ---
        # A model.means_ tartalmazza a 3 rejtett állapot (0,1,2) 3D középértékeit:
        # Oszlopok: 0=Log-ER (negatív értékek), 1=Spread_Elasticity (~1.0), 2=Tick_Density (0 körüli Z-score)
        # Figyelem: A means_ most már Z-score (standardizált) értékeket tartalmaz!
        means = self.model.means_"""

content = content.replace(fit_old, fit_new)

# 4. A predict_state módosítása (itt is transzformálni kell)
predict_old = """    def predict_state(self, log_er, elasticity, z_tick_density):
        \"\"\"Visszaadja a pillanatnyi állapot nevét és az azonosítóját.\"\"\"
        if not self.is_fitted:
            return "Unknown", -1

        obs = np.array([[log_er, elasticity, z_tick_density]])
        hidden_state_idx = self.model.predict(obs)[0]"""

predict_new = """    def predict_state(self, log_er, elasticity, z_tick_density):
        \"\"\"Visszaadja a pillanatnyi állapot nevét és az azonosítóját.\"\"\"
        if not self.is_fitted:
            return "Unknown", -1

        obs = np.array([[log_er, elasticity, z_tick_density]])

        # [ÚJÍTÁS: BEMENET TRANZFORMÁLÁSA A PREDICT ELŐTT]
        obs_scaled = self.scaler.transform(obs)

        hidden_state_idx = self.model.predict(obs_scaled)[0]"""

content = content.replace(predict_old, predict_new)

with open("vaku3_offline_validator_VPS_new.py", "w", encoding="utf-8") as f:
    f.write(content)

print("Patching done.")
