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

    def __init__(self, contamination=0.01, random_state=42):
        super().__init__("IsolationForest")
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
        df['Ping_Diff'] = df['Ping'].diff().fillna(0)

        # Főbb dimenziók kijelölése
        self.features = ['Bid_Diff', 'Spread', 'Spread_Diff', 'Ping', 'Ping_Diff', 'TimeDeltaMsc']

        # Opcionális Volume (ha van a "Naked Sensor"-ban)
        if 'BidVol' in df.columns and 'AskVol' in df.columns:
            df['TotalVol'] = df['BidVol'] + df['AskVol']
            self.features.append('TotalVol')

        logger.info(f"[{self.model_name}] Kiválasztott Feature-ök: {self.features}")
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
