import pytest
import os
import pandas as pd
import numpy as np
import sys
import logging

# Projekt gyökér mappa hozzáadása a relatív importokhoz a pytest futtatásakor
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from pipeline.data_loader import RobustDataLoader
from utils.mock_data_generator import create_mock_tick_data
from models.isolation_forest import IsolationForestDetector
from models.hmm_model import HMMDetector
from models.lstm_autoencoder import LSTMAutoencoderDetector

@pytest.fixture(scope="module")
def mock_csv_path():
    """Generál egy szintetikus CSV-t a teszteléshez, majd a végén törli."""
    filepath = create_mock_tick_data(filepath="test_mock_data.csv", rows=2000)
    yield filepath
    # Takarítás
    if os.path.exists(filepath):
        os.remove(filepath)

def test_data_loader(mock_csv_path):
    """Az 8GB RAM barát data loader betölti-e az adatokat hibátlanul."""
    loader = RobustDataLoader(chunksize=500)
    df = loader.load_tick_data(mock_csv_path)

    assert not df.empty, "A betöltött DataFrame üres!"
    assert len(df) == 2000, f"Várt 2000 sor, kapott {len(df)}."

    # Kritikus Naked Sensor oszlopok ellenőrzése
    required_cols = ['TickMSC', 'Bid', 'Ask', 'Spread', 'Ping']
    for col in required_cols:
        assert col in df.columns, f"Hiányzó oszlop a betöltés után: {col}"

def test_isolation_forest_pipeline(mock_csv_path):
    """Isolation Forest (Néma Színház - Bróker trükk detektor) teljes csővezetékének tesztelése."""
    loader = RobustDataLoader()
    df = loader.load_tick_data(mock_csv_path)

    # Inicializálás
    detector = IsolationForestDetector(contamination="auto", random_state=42)

    # Feature Engineering
    df_processed = detector.preprocess(df)
    assert 'Spread_Diff' in df_processed.columns, "Feature engineering elmaradt!"

    # Betanítás
    detector.train(df_processed)
    assert detector.is_trained, "Modell nem jelzi a betanított státuszt."

    # Detektálás
    df_result = detector.detect(df_processed)
    assert 'Anomaly' in df_result.columns, "Hiányzik az Anomaly predikciós oszlop."
    assert 'Anomaly_Score' in df_result.columns, "Hiányzik a Score oszlop."

    # Biztosan lennie kell legalább egy normál (1) adatsornak
    assert 1 in df_result['Anomaly'].values, "Nem talált egyetlen normál adatot sem (túl aggresszív model?)"

def test_hmm_pipeline_warning(mock_csv_path, caplog):
    """
    HMM tesztelése. Ha nincs telepítve a hmmlearn, akkor graceful fallback-et
    kell adnia (ValueError vagy Exception) összeomlás helyett.
    """
    loader = RobustDataLoader()
    df = loader.load_tick_data(mock_csv_path)

    try:
        import hmmlearn
        has_hmmlearn = True
    except ImportError:
        has_hmmlearn = False

    detector = HMMDetector(n_components=2)
    df_processed = detector.preprocess(df)

    if not has_hmmlearn:
        with pytest.raises(ImportError):
            detector.train(df_processed)
    else:
        # Ha a környezetben telepítve van, a tesztnek le kell futnia.
        detector.train(df_processed)
        df_result = detector.detect(df_processed)
        assert 'BROKER_STATE' in df_result.columns, "Hiányzik a HMM rezsim azonosítója."

def test_lstm_autoencoder_pipeline(mock_csv_path):
    """
    LSTM Autoencoder (Nehéztüzérség) csővezetékének tesztelése.
    Ellenőrzi, hogy a Keras modell nem száll el OOM / Shape hibával,
    képes-e szekvenciákat legenerálni, és az eredmény DataFrame hossza
    pontosan megegyezik-e a bemenettel (a padding ellenére).
    """
    loader = RobustDataLoader()
    df = loader.load_tick_data(mock_csv_path)

    try:
        import tensorflow
        has_tf = True
    except ImportError:
        has_tf = False

    # Nagyon kis paraméterezés a gyors teszteléshez
    detector = LSTMAutoencoderDetector(seq_length=5, latent_dim=2, batch_size=32, epochs=1)

    if not has_tf:
        with pytest.raises(ImportError):
            detector.train(df)
    else:
        # A tesztelés lefut, megnézzük a kimenet oszlopait és a dimenziókat
        detector.train(df)
        assert detector.is_trained, "Az LSTM modell nem jelzi a betanított állapotot."

        # A detektált kimenet hosszának azonosnak kell lennie az eredeti adat hosszával
        df_result = detector.detect(df.copy())
        assert 'LSTM_Reconstruction_Error' in df_result.columns, "MSE hiba oszlop hiányzik"
        assert 'LSTM_Anomaly' in df_result.columns, "Anomália (label) oszlop hiányzik"

        # Ez a legfontosabb teszt a DataFrame ValueError elkerülésére (Padding Hiba)
        assert len(df_result) == len(df), f"Eltörik az index! Bemenet: {len(df)}, Kimenet: {len(df_result)}"
