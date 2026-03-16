from .base_model import BaseModel
import pandas as pd
import numpy as np
import logging
import os
import joblib

# Deep Learning Nehéztüzérség: TensorFlow / Keras Import
try:
    from tensorflow.keras.models import Model, load_model
    from tensorflow.keras.layers import Input, LSTM, RepeatVector, TimeDistributed, Dense
    from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
except ImportError:
    pass

from sklearn.preprocessing import StandardScaler
logger = logging.getLogger(__name__)

class LSTMAutoencoderDetector(BaseModel):
    """
    A Térképszoba (Gemini) 'Nehéztüzérség' Utasítása Alapján Készült Szekvencia-Profilozó AI.

    Ez az Unsupervised Deep Learning hálózat (LSTM Autoencoder) a 49 dimenziós
    (mutlikollineáris) piaci indikátorteret (WPR, EMAs, Stoch, Bid, Spread, stb.)
    időbeli ablakokban (Sliding Window) vizsgálja.

    A háló megpróbálja 'visszaépíteni' (Reconstruct) a normál piaci mozgásokat egy
    szűk látens térből (Bottleneck). Ahol a bróker beavatkozik (Színész tüskék), ott
    a visszaépítési hiba (Reconstruction Error / MSE) az egekbe szökik.
    """

    def __init__(self, seq_length=30, latent_dim=8, batch_size=256, epochs=50):
        super().__init__("LSTM_Autoencoder")
        self.seq_length = seq_length  # Hány tickes ablakot (Lookback) lát a hálózat egyszerre?
        self.latent_dim = latent_dim  # 49 dimenzió -> 8 dimenzió (Tömörítés)
        self.batch_size = batch_size
        self.epochs = epochs

        self.features = []
        self.scaler = StandardScaler()
        self.threshold = 0.0 # Ide kerül a dinamikus hiba küszöbérték (pl. 95. percentilis)

        try:
            from tensorflow.keras.models import Model
        except ImportError:
            logger.error("Kritikus Hiba: A TensorFlow nincs telepítve! (pip install tensorflow)")
            self.model = None

    def _build_model(self, num_features):
        """Felépíti a Keras LSTM Autoencoder Architekturát."""
        if self.model is not None:
            return # Már megépült

        logger.info(f"[{self.model_name}] Hálózat Építése: Input({self.seq_length}, {num_features}) -> Bottleneck({self.latent_dim})")

        # Bemeneti réteg (Tick Ablak Hossza x Feature-ök száma)
        inputs = Input(shape=(self.seq_length, num_features))

        # ENCODER: Idősoros tömörítés
        encoded = LSTM(16, activation='relu', return_sequences=False)(inputs)
        bottleneck = Dense(self.latent_dim, activation='relu')(encoded)

        # DECODER: Visszaépítés a szűk keresztmetszetből
        repeated = RepeatVector(self.seq_length)(bottleneck)
        decoded_lstm = LSTM(16, activation='relu', return_sequences=True)(repeated)
        outputs = TimeDistributed(Dense(num_features))(decoded_lstm)

        self.model = Model(inputs=inputs, outputs=outputs)
        self.model.compile(optimizer='adam', loss='mse')

    def _get_dataset(self, X_scaled: np.ndarray):
        """
        A 'Sliding Window' legfontosabb RAM kímélő megvalósítása.
        Nem hozza létre a memóriában a ~11.7 GB-os gigantikus szekvencia duplikátumot,
        hanem 'on-the-fly' kötegelt Keras Dataset-ként (Generator) húzza fel a RAM-ba batch-enként.
        """
        import tensorflow as tf
        from tensorflow.keras.utils import timeseries_dataset_from_array

        # Mivel az Autoencodernek (Unsupervised) önmagát kell visszaépítenie a szűkített látens térből,
        # a bemenet (X) és az elvárt kimenet (Y / target) dimenziója és tartalma hajszálpontosan megegyezik.

        # Létrehozzuk a bemeneti szekvenciákat tartalmazó adathalmazt (targets=None)
        input_dataset = timeseries_dataset_from_array(
            data=X_scaled,
            targets=None, # Az Autoencoder-nek önmagát kell célként (y) használnia
            sequence_length=self.seq_length,
            sequence_stride=1,
            batch_size=self.batch_size,
            shuffle=False
        )

        # A Keras fit()-hez (x, y) tuple formátum szükséges minden batch-re.
        # A térképező lambda funkcióval a szekvenciát önmagához (x, x) párosítjuk.
        autoencoder_dataset = input_dataset.map(lambda x: (x, x))

        return autoencoder_dataset

    def preprocess(self, df: pd.DataFrame, fit_scaler=False) -> np.ndarray:
        """
        Dinamikusan kinyeri a DataMiner_BlackBox 49 dimenzióját, kitölti a NaN-okat,
        és kötelezően Standardizálja őket (Z-score), hogy a hálózat ne robbanjon fel.
        """
        logger.info(f"[{self.model_name}] Deep Learning Adatelőkészítés (Skálázás és Tisztítás)...")

        exclude_cols = ['Time', 'TickMSC', 'TimeMsc', 'IF_Anomaly', 'IF_Score', 'BROKER_STATE']
        self.features = []

        for col in df.columns:
            if col in exclude_cols:
                continue
            if pd.api.types.is_numeric_dtype(df[col]):
                df[col] = df[col].ffill().fillna(0) # Biztosítjuk a hálózat stabilitását
                self.features.append(col)

        self.features = sorted(list(set(self.features)))
        logger.info(f"[{self.model_name}] Dimenziók száma: {len(self.features)}")

        # Adat kinyerése
        X_raw = df[self.features].values

        # A neurális háló érzékeny a nyers árakra (1.080 vs 100000 Volume),
        # ezért kötelező az értékeket 0 átlag és 1 szórás köré rendezni.
        if fit_scaler:
            X_scaled = self.scaler.fit_transform(X_raw)
        else:
            X_scaled = self.scaler.transform(X_raw)

        return X_scaled

    def train(self, df: pd.DataFrame):
        # Ha nincs tensorflow, dobjon ImportError-t, ahogy a teszt várja (és ne fusson tovább a hiányzó Input miatt)
        try:
            from tensorflow.keras.models import Model
        except ImportError:
            raise ImportError("Kritikus Hiba: A TensorFlow nincs telepítve! (pip install tensorflow)")

        # 1. Először meg kell találni a 49 dimenziót, csak utána épülhet fel a háló
        X_scaled = self.preprocess(df, fit_scaler=True)

        if not self.model:
            self._build_model(len(self.features)) # Most már tudja a dimenziók számát

        logger.info(f"[{self.model_name}] Szekvencia Batch Generátor Indítása (11GB memóriarobbanás kivédve)...")
        dataset = self._get_dataset(X_scaled)

        logger.info(f"[{self.model_name}] LSTM Autoencoder Betanítás Indítása (Batch: {self.batch_size})...")

        callbacks = [
            EarlyStopping(monitor='loss', patience=3, restore_best_weights=True),
            ReduceLROnPlateau(monitor='loss', factor=0.5, patience=2)
        ]

        # Betanítás a memóriakímélő kötegeken
        history = self.model.fit(
            dataset,
            epochs=self.epochs,
            callbacks=callbacks,
            verbose=1
        )

        self.is_trained = True

        logger.info(f"[{self.model_name}] Normál piaci visszaépítési hiba kiszámítása a Thresholdhoz...")

        # MSE kiszámítása kötegenként, hogy ne töltsük be az 1 milliót egyszerre
        mse_list = []
        for batch_x, _ in dataset:
            batch_pred = self.model.predict_on_batch(batch_x)
            batch_mse = np.mean(np.power(batch_x - batch_pred, 2), axis=(1, 2))
            mse_list.extend(batch_mse)

        mse = np.array(mse_list)

        # Küszöb: A hibák felső 5%-a már Anomália
        self.threshold = np.percentile(mse, 95)
        logger.info(f"[{self.model_name}] Autoencoder Betanítva! Kritikus Hiba Küszöb (Threshold): {self.threshold:.5f}")

    def detect(self, df: pd.DataFrame) -> pd.DataFrame:
        if not self.is_trained:
            raise RuntimeError("Nem futtathatsz detektálást egy nem betanított LSTM modellen!")

        logger.info(f"[{self.model_name}] Brókeri Manipuláció Keresése (Reconstruction Error alapján)...")

        X_scaled = self.preprocess(df, fit_scaler=False)
        dataset = self._get_dataset(X_scaled)

        # Visszaépítési hiba számítása batch-enként (OOM védelem)
        mse_list = []
        for batch_x, _ in dataset:
            batch_pred = self.model.predict_on_batch(batch_x)
            batch_mse = np.mean(np.power(batch_x - batch_pred, 2), axis=(1, 2))
            mse_list.extend(batch_mse)

        mse = np.array(mse_list)

        # Mivel a "Sliding Window" miatt a legelső (seq_length - 1) darab tickből nincs
        # teljes ablakunk, azokhoz kipárnázzuk a hibát az első ismert hibával,
        # hogy a kimeneti Dataframe hossza hajszálpontosan megegyezzen az eredetivel.
        padding = [mse[0]] * (self.seq_length - 1)
        full_mse = np.concatenate([padding, mse])

        df['LSTM_Reconstruction_Error'] = full_mse

        # Anomália Detektálás (-1 = Manipulált / Színész beavatkozás, 1 = Normál)
        df['LSTM_Anomaly'] = np.where(df['LSTM_Reconstruction_Error'] > self.threshold, -1, 1)

        toxic_count = len(df[df['LSTM_Anomaly'] == -1])
        logger.info(f"[{self.model_name}] Mélytanulás Elemzés Kész. Talált 'Színész' szekvenciák: {toxic_count} db ({(toxic_count/len(df))*100:.2f}%)")

        return df

    def save(self, base_path: str):
        """Kimenti a modellt és a skálázót (scaler) is!"""
        if not self.is_trained:
            return

        model_file = f"{base_path}_keras.h5"
        scaler_file = f"{base_path}_scaler.pkl"

        self.model.save(model_file)
        joblib.dump({'scaler': self.scaler, 'threshold': self.threshold}, scaler_file)
        logger.info(f"[{self.model_name}] Kimentve: {model_file} és {scaler_file}")

    def load(self, base_path: str):
        from tensorflow.keras.models import load_model

        model_file = f"{base_path}_keras.h5"
        scaler_file = f"{base_path}_scaler.pkl"

        if not os.path.exists(model_file) or not os.path.exists(scaler_file):
            raise FileNotFoundError(f"Nem találom az LSTM fájlokat: {model_file}")

        self.model = load_model(model_file)
        data = joblib.load(scaler_file)
        self.scaler = data['scaler']
        self.threshold = data['threshold']
        self.is_trained = True
        logger.info(f"[{self.model_name}] Sikeresen visszatöltve a memóriába!")
