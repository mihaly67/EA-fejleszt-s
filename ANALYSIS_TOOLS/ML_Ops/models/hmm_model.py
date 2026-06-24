from .base_model import BaseModel
import pandas as pd
import numpy as np
import logging
import warnings

# 'hmmlearn' egy lightweight Hidden Markov Model könyvtár (CPU optimizált, nincs Tensorflow felesleg)
try:
    from hmmlearn.hmm import GaussianHMM
except ImportError:
    # A RAG és Handover utasítások alapján telepíteni kell majd a VPS-en: pip install hmmlearn
    pass

logger = logging.getLogger(__name__)

class HMMDetector(BaseModel):
    """
    A Hidden Markov Model (HMM) a projekt egyik alappillére a rejtett brókeri
    'rezsimek' vagy 'állapotok' azonosítására a tick adatokból.

    Tökéletes CPU-only VPS (8GB) környezethez, mivel nagyon gyorsan képes felvázolni
    pl: [0 = Normál Állapot, 1 = Toxikus Spread / Késleltetés] rezsimeket az áramlásból.
    NEM aggregált, hanem NYERS, event-driven adaton kell futnia (ahogy a handover kéri).
    """

    def __init__(self, n_components=2, random_state=42):
        super().__init__("HMM_Regime_Detector")
        self.n_components = n_components  # Pl. 2 rezsim: Normál vs. Manipulált
        self.random_state = random_state
        self.features = []

        try:
            from hmmlearn.hmm import GaussianHMM
            self.model = GaussianHMM(
                n_components=self.n_components,
                covariance_type="diag",  # Térképszoba Utasítás: A 48 dimenziós Multikollinearitás elkerülése
                n_iter=100,
                random_state=self.random_state
            )
        except ImportError:
            logger.error("A 'hmmlearn' csomag hiányzik. Kérlek telepítsd: pip install hmmlearn")
            self.model = None

    def preprocess(self, df: pd.DataFrame) -> pd.DataFrame:
        """Kiválasztja a HMM számra az idősoros dimenziókat (Z-Score vagy Diffelés ajánlott)."""
        logger.info(f"[{self.model_name}] HMM Feature Engineering...")

        # Alapvető volatilitás és sebesség dimenziók a rejtett állapotok kereséséhez
        # DINAMIKUS FEATURE MAPPING (ZÉRÓ HARDKÓDOLÁS)
        # Az összes DataMiner_BlackBox által generált oszlop az "Állapottér" része a HMM-ben.
        # Nincs felesleges válogatás. Ami a CSV-ben van, az kell az AI-nak.

        exclude_cols = ['Time', 'TickMSC', 'TimeMsc']
        self.features = []

        # A HMM szereti a relatív változásokat a nyers árak (1.08552) helyett
        if 'Bid' in df.columns:
            df['Bid_Return'] = df['Bid'].pct_change().fillna(0)
            self.features.append('Bid_Return')

        for col in df.columns:
            if col in exclude_cols or col == 'Bid_Return':
                continue

            # Csak a matematikai adatokat engedjük be (nem stringet)
            if pd.api.types.is_numeric_dtype(df[col]):
                df[col] = df[col].ffill() # HMM elhasalna egy NaN értéken!
                self.features.append(col)

        # Nagyon fontos: A HMM az időbeli szekvenciákat tanulja, így az indikátorok
        # folyamatos eloszlása fogja meghatározni a brókeri makro állapotot (rezsimet).

        logger.info(f"[{self.model_name}] Összes HMM Dimenzió betöltve: {len(self.features)} db")
        return df

    def train(self, df: pd.DataFrame):
        if not self.model:
             raise ImportError("HMM modell nem inicializálható 'hmmlearn' csomag nélkül.")
        if not self.features:
            raise ValueError("Kérlek futtasd a preprocess() eljárást a DF-en!")

        logger.info(f"[{self.model_name}] HMM betanítás {self.n_components} rejtett állapot keresésével...")

        # Az X adat 2D array formában kell bemenjen
        X = df[self.features].values

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            self.model.fit(X)

        self.is_trained = True
        logger.info(f"[{self.model_name}] HMM betanítás kész. Konvergencia: {self.model.monitor_.converged}")

    def detect(self, df: pd.DataFrame) -> pd.DataFrame:
        if not self.is_trained:
            raise RuntimeError("Nincs betanítva a HMM modell!")

        logger.info(f"[{self.model_name}] Rezsimek felismerése (0, 1... állapotok) az adatsoron...")
        X = df[self.features].values

        # A 'predict' visszaadja a legvalószínűbb Viterbi állapotokat minden tickhez
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            hidden_states = self.model.predict(X)

        df['BROKER_STATE'] = hidden_states

        # A HMM esetében nincs klasszikus -1 anomália, így szimuláljuk az egységes API-hoz:
        # Tegyük fel, hogy a nagyobb varianciájú/átlagú állapot a manipulált. (Egyszerű logika a mockhoz).
        # Ez valós produkcióban a Spread/Ping átlagok összehasonlításával finomítandó.
        state_means = {s: df[df['BROKER_STATE'] == s]['Spread'].mean() for s in range(self.n_components)}
        toxic_state = max(state_means, key=state_means.get)

        df['Anomaly'] = np.where(df['BROKER_STATE'] == toxic_state, -1, 1)
        df['Anomaly_Score'] = df['BROKER_STATE'] # Placeholder: HMM-nél ez a kategória maga

        toxic_count = len(df[df['Anomaly'] == -1])
        logger.info(f"[{self.model_name}] Rezsimek elkülönítve. A feltételezett '{toxic_state}' (toxikus) állapot hossza: {toxic_count} tick.")

        return df
