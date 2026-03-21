import numpy as np
import pandas as pd
from collections import deque
import logging
from .lstm_autoencoder import LSTMAutoencoderDetector

logger = logging.getLogger(__name__)

class RollingLSTMAutoencoder(LSTMAutoencoderDetector):
    """
    Állapotmegtartó (Stateful) Online Autoencoder, amely egy memóriában (deque)
    tárolja a legutolsó N ticket (rolling window), hogy szimulálja a valós idejű
    anomália detektálást az élő MT5 hídon (vagy a Virtual Streameren).

    A dtaianomaly könyvtárra támaszkodva a deque maximális mérete dinamikusan
    újrakalibrálható (pl. 82 tickről 40-re, ha a volatilitás megváltozik).
    """

    def __init__(self, initial_seq_length=82, latent_dim=8):
        # A Batch size itt értelmetlen az élő streamnél, mert 1 db ablakot vizsgálunk
        # Az epochs=1 csak a placeholdernél számít (mivel itt nem batch learning lesz)
        super().__init__(seq_length=initial_seq_length, latent_dim=latent_dim, batch_size=1, epochs=1)

        # Ez a belső memória (buffer). Automatikusan eldobja a régi elemeket, ha megtelik
        self.memory = deque(maxlen=self.seq_length)
        self.feature_names = [] # Később feltöltődik az első tick oszlopaiból

    def update_window_size(self, new_seq_length: int):
        """
        Dinamikus ablakméret váltás futás közben! (Szekvencia Önadaptáció)
        A kalibrációs szál (Time-Bucketing) hívja meg ezt, ha a dtaianomaly
        kiszámolja az új domináns frekvenciát.
        """
        if new_seq_length == self.seq_length:
            return

        logger.info(f"[Rolling LSTM] Memória Méretezés: {self.seq_length} -> {new_seq_length} tick")
        self.seq_length = new_seq_length

        # Új, átméretezett deque létrehozása, átemelve az eddigi (maximálisan beférő) múltbeli tickeket
        new_memory = deque(self.memory, maxlen=self.seq_length)
        self.memory = new_memory

        # A Keras hálózat input layer-e (seq_length, features) méretű.
        # Ha megváltozik a seq_length, a Keras hálót sajnos újra kell fordítani
        # a megfelelő bemeneti dimenziókkal!
        self.model = None # Kikényszeríti az újraépítést a következő detect-nél
        self.is_trained = False # A súlyok (weights) is elvesznek, tehát újra is kell tanítani a bázisra!

    def add_tick(self, tick_data: dict) -> bool:
        """
        Egy új tick beillesztése a memóriába.
        Ha a memória megtelt (elérte a seq_length-t), visszaadja a 'True' értéket,
        jelezve, hogy az ablak készen áll a detektálásra.
        """
        # Feature-ök inicializálása az első tickből
        if not self.feature_names:
            excluded_prefixes = ('Trade_', 'Order_', 'PosCount', 'Balance', 'Phase', 'Lot', 'Profit')
            excluded_exact = ('Time', 'TickMSC', 'TimeMsc')
            for key, value in tick_data.items():
                if not key.startswith(excluded_prefixes) and key not in excluded_exact and isinstance(value, (int, float)):
                     self.feature_names.append(key)
            self.features = self.feature_names

        # Nyers értékek kinyerése szigorú sorrendben, alapértelmezett érték kezeléssel
        raw_values = []
        for k in self.feature_names:
            val = tick_data.get(k, 0.0)
            # Konverzió np.nan esetén (pandas iterrows miatt)
            if pd.isna(val):
                val = 0.0
            raw_values.append(val)

        # Memória frissítése
        self.memory.append(raw_values)

        return len(self.memory) == self.seq_length

    def predict_current_window(self) -> float:
        """
        A memóriában tárolt aktuális ablakra (utolsó N tick) kiszámítja a
        Visszaépítési Hibát (Reconstruction Error / MSE).
        (Csak akkor hívható, ha a memória már tele van!)
        """
        if len(self.memory) < self.seq_length:
            return 0.0 # Még épül az ablak, nincs hiba

        if not self.is_trained or self.model is None:
            raise RuntimeError("A Rolling LSTM modellt be kell tanítani a történelmi adatokon, mielőtt élőben detektálna!")

        # Memória Pandas DataFrame-é alakítása (hogy a scaler működjön)
        df_window = pd.DataFrame(list(self.memory), columns=self.feature_names)

        # Standardizálás a korábban (kalibrációkor) betanított scaler-rel
        X_raw = df_window.values
        X_scaled = self.scaler.transform(X_raw)

        # Keras (Batch=1, Seq_length, Features) input formázása
        # Mivel ez egyetlen ablak (ablak formátum: (1, seq, features)), nem generátort használunk, hanem sima Numpy array-t
        input_tensor = np.expand_dims(X_scaled, axis=0)

        # Predikció (gyors, OOM mentes egyetlen adatsoron)
        pred_tensor = self.model.predict(input_tensor, verbose=0)

        # MSE hiba számítása (axis=1 és 2-n átlagolva az egyetlen batch-re)
        mse = np.mean(np.power(input_tensor - pred_tensor, 2))

        return mse

    def evaluate_state(self, mse: float) -> str:
        """
        A beállított dinamikus küszöbérték alapján eldönti, hogy a piac
        Normál (Valós) vagy Manipulált (Actor/Bróker) állapotban van-e.
        """
        if mse > self.threshold:
            return "STATE_ACTOR" # Mesterséges zaj, rángatás
        else:
            return "STATE_MARKET" # Tiszta piaci mozgás, kitörés
