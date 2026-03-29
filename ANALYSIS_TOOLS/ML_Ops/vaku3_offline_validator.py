import os
import glob
import pandas as pd
import numpy as np
import logging
from collections import deque
from hmmlearn import hmm

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class NumpyRingBuffer:
    """O(1) sebességű Sliding Window a memóriakímélő 2. mag (Feature Engineering) számára."""
    def __init__(self, capacity, dtype=float):
        self.capacity = capacity
        self.buffer = np.zeros(capacity, dtype=dtype)
        self.index = 0
        self.is_full = False

    def append(self, value):
        self.buffer[self.index] = value
        self.index += 1
        if self.index == self.capacity:
            self.index = 0
            self.is_full = True

    def get_data(self):
        if not self.is_full:
            return self.buffer[:self.index]
        return np.concatenate((self.buffer[self.index:], self.buffer[:self.index]))


class WelfordScaler:
    """
    Online normalizálás Look-ahead bias és memóriatúlcsordulás nélkül.
    Minden ticknél frissíti az átlagot és a szórást, majd visszaadja a Z-Score-t.
    """
    def __init__(self):
        self.n = 0
        self.mean = 0.0
        self.M2 = 0.0

    def update_and_scale(self, x):
        self.n += 1
        delta = x - self.mean
        self.mean += delta / self.n
        delta2 = x - self.mean
        self.M2 += delta * delta2

        if self.n < 2:
            return 0.0

        variance = self.M2 / (self.n - 1)
        std_dev = np.sqrt(variance)

        if std_dev == 0:
            return 0.0

        return (x - self.mean) / std_dev


class Vaku3OfflineValidator:
    """
    A 'Smoking Gun' Bizonyíték Kályhája: Összeköti a Vaku 3.0 (HMM, CUSUM IAT, ER)
    állapotfelmérését a tegnapi (label_broker_reaction.py) Célváltozókkal (TARGET=1).
    Célja bebizonyítani, hogy a HMM melyik állapota korrelál legerősebben a Brókeri
    Manipulációval (Színházzal / Adverse Excursion) az 1-10 tickes éles ablakokban.
    """
    # A window_size-t radikálisan levisszük 15-re, hogy a HMM ugyanolyan rövidlátó,
    # de tűéles "mikro-reakció" érzékelést kapjon a zajról (ER, Spread), mint a 10 tickes Címkézőnk!
    def __init__(self, window_size=15):
        self.window_size = window_size
        self.price_buffer = NumpyRingBuffer(window_size)
        self.spread_buffer = NumpyRingBuffer(window_size)

        # A Vaku 3.0 Welford Skálázója a Tick Density-hez
        self.tick_density_scaler = WelfordScaler()

        # A 3-D Ortogonális Observation Space
        self.observation_space = []

        # A HMM modell (covariance_type="diag" a Singluar Matrix elkerülésére!)
        self.model = hmm.GaussianHMM(n_components=3, covariance_type="diag", n_iter=100, random_state=42)
        self.is_fitted = False

        # Szuper fontos: a szegmentált állapotok Semantic Map-je
        self.state_map = {"Quiet": 0, "Concrete": 1, "Theater": 2} # Csak placeholder, a fit után felülírjuk

    def _calculate_log_er(self):
        prices = self.price_buffer.get_data()
        if len(prices) < 2:
            return 0.0

        # Net elmozdulás (Kezdő és végpont távolsága)
        net_change = np.abs(prices[-1] - prices[0])
        # Bruttó út (Összes mikromozgás)
        path_length = np.sum(np.abs(np.diff(prices)))

        if path_length == 0:
            return 0.0

        # Log-Efficiency Ratio a Gemini javaslata alapján (Fraktális dimenzió)
        # Ha a bróker csak rángat (Színház), a net_change kicsi, a path nagy -> ER a béka segge alatt
        er = net_change / path_length
        # Védjük a logaritmust a nullától
        er = max(1e-6, er)
        return np.log(er)

    def _calculate_spread_elasticity(self):
        spreads = self.spread_buffer.get_data()
        if len(spreads) < 2:
            return 1.0 # Alapállapot

        current_spread = spreads[-1]
        # Egyszerű SMA a helyi Spread ema helyett (a buffer O(1) sebességéhez mérten)
        local_avg = np.mean(spreads)

        if local_avg == 0:
            return 1.0

        return current_spread / local_avg

    def extract_features(self, df):
        """A CSV bejárása (Generator-like loop) a 3D ortogonális vektor felépítéséhez."""
        logger.info(f"O(1) Vektorizált Feature Extraction indítása a {len(df)} ticken...")

        features = []
        for i in range(len(df)):
            bid = df.loc[i, 'Bid']
            spread = df.loc[i, 'Spread'] if 'Spread' in df.columns else 1.0

            # CUSUM IAT Reziduál logikához közeli Tick Density
            # Nincs Volume az MT5-ben, így a Time_Delta inverzével (Sebesség) operálunk.
            latency_ms = df.loc[i, 'Time_Delta_MS'] if 'Time_Delta_MS' in df.columns else 100.0
            tick_speed = 1000.0 / max(1.0, latency_ms) # Hány tick érkezne másodpercenként?

            self.price_buffer.append(bid)
            self.spread_buffer.append(spread)

            # Welford Online Scaling a Tick Density-re (Z-Score)
            z_tick_density = self.tick_density_scaler.update_and_scale(tick_speed)

            if i >= self.window_size:
                log_er = self._calculate_log_er()
                elasticity = self._calculate_spread_elasticity()

                # Az Orthogonal Observation Space: [Log-ER, Spread Elasticity, Z-Tick Density]
                features.append([log_er, elasticity, z_tick_density])
            else:
                # Bemelegedési fázis (Warm-up)
                features.append([0.0, 1.0, 0.0])

        self.observation_space = np.array(features)
        return self.observation_space

    def fit_and_map_states(self):
        """HMM betanítása és a Semantic Mapping ('Ördögűzés') elvégzése a Gemini alapján."""
        if len(self.observation_space) < 100:
            logger.warning("Nincs elég adat a HMM betanításához!")
            return

        logger.info("Vaku 3.0 (GaussianHMM) betanítása az Ortogonális téren (Covar=Diag)...")
        self.model.fit(self.observation_space)
        self.is_fitted = True

        # --- SEMANTIC MAPPING (Az Öntanuló 'Színház' felismerés javított standardizálása) ---
        # A model.means_ tartalmazza a 3 rejtett állapot (0,1,2) 3D középértékeit:
        # Oszlopok: 0=Log-ER (negatív értékek), 1=Spread_Elasticity (~1.0), 2=Tick_Density (0 körüli Z-score)
        means = self.model.means_

        # Indexek a mátrixban
        er_idx = 0
        spread_idx = 1
        tick_idx = 2

        # Mivel a Log-ER és a Spread teljesen más dimenziók (negatív vs pozitív),
        # a nyers kivonás torzít. Skálázzuk (Z-score) mindkét oszlopot 0-1 átlag köré, hogy igazságos legyen a verseny!
        from sklearn.preprocessing import StandardScaler
        scaler = StandardScaler()
        scaled_means = scaler.fit_transform(means)

        # A HMM a Spread apró (0.99x - 1.01x) mozgásait a StandardScaler (Z-score) miatt aránytalanul felnagyítja,
        # ami elnyomja a brutális Log-ER (Hatékonyság) különbségeket (-1.21 vs -13.82).
        # A "Színház" (Manipulált) állapot elsődleges ismérve a ZAJ (a legalacsonyabb / legnegatívabb Log-ER).
        # Ezért a "Theater" kiválasztását TISZTÁN a legalacsonyabb nyers Log-ER értékre kell bízni!
        theater_state = int(np.argmin(means[:, er_idx]))

        # Concrete (Betonfal): A leghatékonyabb, legtisztább haladás (Maximum ER, azaz Legkevésbé Negatív, pl. -1.21).
        concrete_state = int(np.argmax(means[:, er_idx]))

        # Biztonsági ellenőrzés (ha a gép valamiért nem 3, hanem csak 2 érdemi állapotot talált)
        if concrete_state == theater_state:
            logger.warning("Figyelem: A HMM nem tudta elszeparálni a Színházat a Betonfaltól!")

        # Quiet (Csend/Döglött): Ami kimarad
        states = set([0, 1, 2])
        states.discard(theater_state)
        states.discard(concrete_state)
        quiet_state = int(list(states)[0])

        self.state_map = {
            "Quiet": quiet_state,
            "Concrete": concrete_state,
            "Theater": theater_state
        }

        logger.info(f"💡 HMM Szemantikus Térkép elkészült (Tiszta Log-ER alapján)!")
        logger.info(f"  -> Színház (Manipuláció) Állapot ID: {theater_state} | Jellemzők -> LogER: {means[theater_state, er_idx]:.2f}, Spread: {means[theater_state, spread_idx]:.2f}x")
        logger.info(f"  -> Betonfal (Tiszta Trend) Állapot ID: {concrete_state} | Jellemzők -> LogER: {means[concrete_state, er_idx]:.2f}, Spread: {means[concrete_state, spread_idx]:.2f}x")
        logger.info(f"  -> Csendes (Flat) Állapot ID: {quiet_state} | Jellemzők -> LogER: {means[quiet_state, er_idx]:.2f}, Spread: {means[quiet_state, spread_idx]:.2f}x")

    def run_smoking_gun_validation(self, df):
        """
        Az Offline Validációs Protokoll.
        Összeveti a HMM 'Theater' jelzéseit az Adatbázisban lévő (előre felcímkézett)
        Broker_Reaction_Target = 1 (Rám Ugrás/SL Vadászat) eseményekkel.
        """
        if not self.is_fitted:
            self.fit_and_map_states()

        logger.info("HMM Állapotok visszafejtése a teljes adatsoron (Viterbi dekódolás)...")
        hidden_states = self.model.predict(self.observation_space)
        df['Vaku3_HMM_State'] = hidden_states

        # Megjelöljük szövegesen is
        state_names = {v: k for k, v in self.state_map.items()}
        df['Vaku3_State_Name'] = df['Vaku3_HMM_State'].map(state_names)

        # --- A "SMOKING GUN" MATRIKA (Causal Trigger Validation) ---
        if 'Broker_Reaction_Target' not in df.columns:
            logger.warning("A fájl nincs felcímkézve! Futtasd a label_broker_reaction.py-t először!")
            return df

        # Kigyűjtjük azokat az eseteket (Trade-eket), amiket 'Manipulációnak' (Target=1) ítélt a Címkéző (Kályha)
        manipulated_entries = df[df['Broker_Reaction_Target'] == 1].index.tolist()
        total_manipulations = len(manipulated_entries)

        if total_manipulations == 0:
            logger.warning("Nincs Target=1 esemény a fájlban. A validáció skippelve.")
            return df

        # Minden HMM állapotra megnézzük, hányszor jelezte előre a brókeri reakciót (Hit Rate minden Állapotra!)
        # Ezáltal kibukik, ha a HMM mást tartott "Színháznak" a nyers mátrix statisztika alapján.
        state_hits = {0: 0, 1: 0, 2: 0}

        for idx in manipulated_entries:
            # A trade pillanatában (illetve egy nagyon picit előtte lévő) HMM állapot
            hmm_state_at_trade = df.loc[idx, 'Vaku3_HMM_State']
            state_hits[hmm_state_at_trade] += 1

        logger.info(f"\n--- SMOKING GUN BIZONYÍTÉK (Offline Causal Validation) ---")
        logger.info(f"Összes megjelölt Brókeri Reakció (Target=1): {total_manipulations} db")

        for state_id, hits in state_hits.items():
            hit_rate = (hits / total_manipulations) * 100
            state_name = state_names[state_id]
            is_theater = " <--- (Ez a mi kijelölt 'Theater' állapotunk)" if state_name == "Theater" else ""
            logger.info(f"  -> {state_name} (Állapot ID: {state_id}) találati aránya a trükkök előtt: {hits} db ({hit_rate:.1f}%){is_theater}")

        # Most csekkoljuk le a TISZTA trade-eket is (Target=0), nehogy kiderüljön, hogy az 1.8% csak véletlen!
        clean_entries = df[(df['Broker_Reaction_Target'] == 0) & ((df['PosCount'] > df['PosCount'].shift(1)) | (df['PosCount'] < df['PosCount'].shift(1)))].index.tolist()
        total_clean = len(clean_entries)
        if total_clean > 0:
            clean_state_hits = {0: 0, 1: 0, 2: 0}
            for idx in clean_entries:
                hmm_state_at_trade = df.loc[idx, 'Vaku3_HMM_State']
                clean_state_hits[hmm_state_at_trade] += 1

            logger.info(f"\n--- KONTROLL CSOPORT (Target=0 Tiszta Piac, Trade Nyitás/Zárás) ---")
            logger.info(f"Összes megjelölt Tiszta Trade: {total_clean} db")
            for state_id, hits in clean_state_hits.items():
                hit_rate = (hits / total_clean) * 100
                state_name = state_names[state_id]
                logger.info(f"  -> {state_name} (Állapot ID: {state_id}) jelenléte tiszta piacon: {hits} db ({hit_rate:.1f}%)")

        return df

def run_validator():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    labeled_dir = os.path.join(base_dir, 'data', 'labeled')

    csv_files = glob.glob(os.path.join(labeled_dir, 'LABELED_*.csv'))

    if not csv_files:
        logger.warning(f"Nincsenek LABELED_ fájlok a {labeled_dir} mappában! Futtasd a címkézőt!")
        return

    for file in csv_files:
        file_name = os.path.basename(file)
        logger.info(f"\n[VAKU 3.0] Offline Kályha Validáció indítása: {file_name}")

        df = pd.read_csv(file)
        validator = Vaku3OfflineValidator(window_size=15) # A Címkéző (10 tick) fókuszához igazítva

        # 1. Ortogonális Feature Kinyerés
        validator.extract_features(df)

        # 2. HMM Betanítás és Szemantikus Térképezés + Validáció
        df_validated = validator.run_smoking_gun_validation(df)

        # Kimentjük a HMM állapotokkal bővített fájlt
        output_file = os.path.join(labeled_dir, f"VAKU3_VALIDATED_{file_name}")
        df_validated.to_csv(output_file, index=False)
        logger.info(f"Bizonyíték kimentve: {output_file}")

if __name__ == '__main__':
    run_validator()