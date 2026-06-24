from abc import ABC, abstractmethod
import pandas as pd
import logging

logger = logging.getLogger(__name__)

class BaseModel(ABC):
    """
    Közös ősosztály minden anomália detektor modellhez (Pluggable Architecture).
    Biztosítja az egységes API-t a teljes MLOps pipeline számára.
    """

    def __init__(self, model_name: str):
        self.model_name = model_name
        self.is_trained = False
        self.model = None

    @abstractmethod
    def preprocess(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Adat-specifikus feature engineering (pl. diff, rolling window), ami
        az adott modellhez szükséges.
        Minden alosztálynak magának kell implementálnia.
        """
        pass

    @abstractmethod
    def train(self, df: pd.DataFrame):
        """
        Unsupervised vagy Semi-supervised modell betanítása.
        """
        pass

    @abstractmethod
    def detect(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Prediktálja az anomáliákat.
        Elvárás, hogy egy új DataFrame-et adjon vissza 'Anomaly' (1=normál, -1=anomália)
        és 'Anomaly_Score' oszlopokkal kibővítve.
        """
        pass

    def save(self, file_path: str):
        """Elmenti a modellt (pl. joblib vagy pickle formátumban)."""
        import joblib
        if not self.is_trained:
            logger.warning("Figyelem: Nem betanított modellt mentesz el!")
        joblib.dump(self.model, file_path)
        logger.info(f"[{self.model_name}] Sikeresen elmentve ide: {file_path}")

    def load(self, file_path: str):
        """Betölti a lementett modellt."""
        import joblib
        import os
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"Nem található lementett modell: {file_path}")
        self.model = joblib.load(file_path)
        self.is_trained = True
        logger.info(f"[{self.model_name}] Sikeresen betöltve innen: {file_path}")
