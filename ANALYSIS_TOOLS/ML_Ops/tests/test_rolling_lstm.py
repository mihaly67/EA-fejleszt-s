import pytest
import pandas as pd
import numpy as np
import os
from models.rolling_lstm import RollingLSTMAutoencoder

def test_rolling_lstm_initialization():
    """Alap inicializálás és öröklés ellenőrzése."""
    model = RollingLSTMAutoencoder(initial_seq_length=5)
    assert model.seq_length == 5
    assert len(model.memory) == 0
    assert model.batch_size == 1

def test_rolling_lstm_add_tick_and_window_size():
    """Tick adagolás (deque hossza) és a dinamikus átméretezés működése."""
    model = RollingLSTMAutoencoder(initial_seq_length=3)

    # Próba tickek generálása
    ticks = [
        {'TickMSC': 1, 'Bid': 1.0, 'Ask': 1.1},
        {'TickMSC': 2, 'Bid': 2.0, 'Ask': 2.1},
        {'TickMSC': 3, 'Bid': 3.0, 'Ask': 3.1},
        {'TickMSC': 4, 'Bid': 4.0, 'Ask': 4.1}
    ]

    # 1. tick: nem telt meg
    assert model.add_tick(ticks[0]) is False
    assert len(model.memory) == 1

    # Feature map inicializálódott és kikerültek az 'TickMSC' oszlopok
    assert 'Bid' in model.feature_names
    assert 'Ask' in model.feature_names
    assert 'TickMSC' not in model.feature_names

    # 2. tick
    model.add_tick(ticks[1])
    # 3. tick: megtelt!
    assert model.add_tick(ticks[2]) is True
    assert len(model.memory) == 3

    # 4. tick hozzáadása (Rolling window: az első kilökődik)
    model.add_tick(ticks[3])
    assert len(model.memory) == 3

    # Dinamikus átméretezés 5-re
    model.update_window_size(5)
    assert model.seq_length == 5
    assert len(model.memory) == 3 # A régiek megmaradtak

    # És elveszítette a betanítását, mert újra kell majd compilálni
    assert model.is_trained is False
