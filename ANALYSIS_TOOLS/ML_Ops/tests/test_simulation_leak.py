import pytest
import pandas as pd
import numpy as np
import os
from pipeline.virtual_streamer import VirtualClockStreamer
from run_streaming_simulation import extract_recent_history

@pytest.fixture
def mock_csv_file(tmp_path):
    """Létrehoz egy egyszerű mock CSV fájlt milliszekundum időbélyegekkel"""
    file_path = tmp_path / "mock_ticks_leak.csv"

    df = pd.DataFrame({
        'TickMSC': [1000, 2000, 3000, 4000, 5000, 6000000],
        'Bid': [1.1000, 1.1001, 1.1002, 1.1005, 1.1004, 1.1008]
    })

    df.to_csv(file_path, index=False)
    return str(file_path)

def test_extract_recent_history_no_leak(mock_csv_file):
    """
    Kritikus Biztonsági Teszt: A kalibrációs algoritmus SOSEM kaphatja meg
    az aktuális ticket (jövőbe látás megelőzése), csak azokat a tickeket, amik
    már a virtuális óra ELŐTT (strictly less than) történtek.
    """
    streamer = VirtualClockStreamer(mock_csv_file)

    # Léptetünk a 3. tickig (Time: 3000 ms)
    generator = streamer.stream_ticks()
    next(generator) # 1000
    next(generator) # 2000
    t3, data3 = next(generator) # 3000

    assert streamer.virtual_clock == 3000

    # 1. Kinyerjük a múltat (Mivel a lookback mondjuk 1 óra, az összes eddigi bekerülhet)
    # De az aktuális (t3 = 3000 ms) TICK NEM LEHET BENNE!
    history = extract_recent_history(streamer, lookback_minutes=60.0)

    assert len(history) == 2 # Csak az 1000 és 2000 ms tickeket kaphatja meg!
    assert 3000 not in history['TickMSC'].values
    assert 4000 not in history['TickMSC'].values # És persze a jövő sem

    # 2. Továbblépés a jövőbe (Time: 6000000 ms, kb. 100 perc)
    next(generator) # 4000
    next(generator) # 5000
    t6, data6 = next(generator) # 6000000

    assert streamer.virtual_clock == 6000000

    # Lookback 100 perc, tehát benne kell lennie a korábbiaknak (1000-5000)
    # De a 6000000-nak (aktuális) nem!
    history2 = extract_recent_history(streamer, lookback_minutes=100.0)

    assert len(history2) == 5
    assert 6000000 not in history2['TickMSC'].values
