from .base_model import BaseModel
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
import logging

logger = logging.getLogger(__name__)

class IsolationForestDetector(BaseModel):
    """
    Az 'Néma Színház' (Naked Sensor) projekt első számú védelmi vonala
    brókeri tick manipulációk és anomáliák felismerésére (Scikit-Learn).

    Nem igényel címkézett adatot (Unsupervised), nagyon robosztus a nagy
    dimenziós adatok (pl. gyorsulás, spread tüskék) klaszterezésében.
    """

    def __init__(self, contamination="auto", random_state=42):
        super().__init__("IsolationForest")
        # Térképszoba Utasítás: Levettük a pórázt az AI-ról, automatikusan keresi a küszöböt
        self.contamination = contamination
        self.random_state = random_state
        self.features = []
        self.model = IsolationForest(
            n_estimators=100,
            contamination=self.contamination,
            random_state=self.random_state,
            n_jobs=-1 # Párhuzamosítja az összes CPU magot a VPS-en
        )

    def preprocess(self, df: pd.DataFrame) -> pd.DataFrame:
        """Kiszámítja az anomália kereséshez szükséges diff és flow változókat."""
        logger.info(f"[{self.model_name}] Feature Engineering indítása {len(df)} soron...")

        # Időalapú delta a tick burstök és késleltetések figyelésére
        df['TimeDeltaMsc'] = df['TickMSC'].diff().fillna(0)

        # Árfolyam gyorsulás
        df['Bid_Diff'] = df['Bid'].diff().fillna(0)

        # Brókeri spread manipuláció és ping/szerver-oldali delay-ek
        df['Spread_Diff'] = df['Spread'].diff().fillna(0)

        # MT5 Data Miner (v1.00) esetén Ping_MS a neve
        ping_col = 'Ping_MS' if 'Ping_MS' in df.columns else 'Ping'
        if ping_col in df.columns:
             df['Ping_Diff'] = df[ping_col].diff().fillna(0)

        # DINAMIKUS FEATURE MAPPING (ZÉRÓ HARDKÓDOLÁS)
        # Az összes oszlop, amit a DataMiner_BlackBox legenerált, fontos a detektornak.
        # Csak a string vagy értelmezhetetlen idő metaadatokat hagyjuk ki a szoros matematikai térből.

        exclude_cols = ['Time', 'TickMSC', 'TimeMsc']
        self.features = []

        for col in df.columns:
            if col in exclude_cols:
                continue

            # Csak numerikus adatok érdeklik az Isolation Forestet
            if pd.api.types.is_numeric_dtype(df[col]):
                df[col] = df[col].ffill() # Törtérték, ha hiányozna
                self.features.append(col)

                # A tüskékhez (spike) fontos az 1 lépéses differencia
                # Pl. a WPR hirtelen megugrása, vagy Ping késleltetés a fontos a modellnek, nem csak az érték
                if col not in ['Bid_Diff', 'Spread_Diff', 'Ping_Diff', 'TimeDeltaMsc']:
                    diff_col_name = f"{col}_Diff"
                    df[diff_col_name] = df[col].diff().fillna(0)
                    self.features.append(diff_col_name)

        # Kód-ellenőrzés javítás: Ha az előre kiszámított "Bid_Diff" vagy "Ping_Diff"
        # bent maradt a loop-ban, ne szerepeljen kétszer a modell feature halmazában.
        # A sorted() garantálja, hogy a feature lista determinisztikus maradjon különböző futások között.
        self.features = sorted(list(set(self.features)))

        logger.info(f"[{self.model_name}] Összes dinamikusan felvett Feature (Egyedi Dimenzió: {len(self.features)} db)")
        return df

    def train(self, df: pd.DataFrame):
        if not self.features:
            raise ValueError("Kérlek először hívd meg a preprocess() függvényt az adaton!")

        logger.info(f"[{self.model_name}] Betanítás (Isolation Forest) indítása...")
        X = df[self.features].values
        self.model.fit(X)
        self.is_trained = True
        logger.info(f"[{self.model_name}] Modell sikeresen betanítva!")

    def detect(self, df: pd.DataFrame) -> pd.DataFrame:
        if not self.is_trained:
            raise RuntimeError("Nem futtathatsz detektálást egy nem betanított modellen!")

        logger.info(f"[{self.model_name}] Predikció futtatása (1 = Normál, -1 = Anomália)")
        X = df[self.features].values

        df['Anomaly'] = self.model.predict(X)
        df['Anomaly_Score'] = self.model.decision_function(X) # Negatív értékek jelentik a durva eltéréseket

        anomalies_count = len(df[df['Anomaly'] == -1])
        logger.info(f"[{self.model_name}] Talált Anomáliák száma: {anomalies_count} ({(anomalies_count/len(df))*100:.2f}%)")

        return df
