import pytest
import pandas as pd
import numpy as np
import os
from pipeline.virtual_streamer import VirtualClockStreamer

@pytest.fixture
def mock_csv_file(tmp_path):
    """Létrehoz egy egyszerű mock CSV fájlt milliszekundum időbélyegekkel"""
    file_path = tmp_path / "mock_ticks.csv"

    # Két tick közt 10 másodperc (10000 ms), majd 1 perces lyuk
    df = pd.DataFrame({
        'TickMSC': [1000000, 1010000, 1020000, 1080000, 1090000],
        'Bid': [1.1000, 1.1001, 1.1002, 1.1005, 1.1004],
        'Ask': [1.1001, 1.1002, 1.1003, 1.1006, 1.1005]
    })

    df.to_csv(file_path, index=False)
    return str(file_path)


def test_virtual_clock_initialization(mock_csv_file):
    streamer = VirtualClockStreamer(mock_csv_file)
    assert streamer.total_rows == 5
    assert streamer.time_col == 'TickMSC'
    assert streamer.start_time == 1000000
    assert streamer.virtual_clock == 1000000


def test_virtual_clock_progression(mock_csv_file):
    """
    Ellenőrzi, hogy a virtuális óra a generátorban tickenként lépked,
    kivárás nélkül, és az eltelt idő percben helyes (60000 ms = 1 perc).
    """
    streamer = VirtualClockStreamer(mock_csv_file)

    # 1. tick
    generator = streamer.stream_ticks()
    t1, data1 = next(generator)
    assert t1 == 1000000
    assert streamer.get_elapsed_time_minutes() == 0.0

    # 2. tick
    t2, data2 = next(generator)
    assert t2 == 1010000
    assert streamer.virtual_clock == 1010000
    assert data2['Bid'] == 1.1001

    # A negyedik ticknél a különbség 80000 ms (azaz több mint 1 perc)
    t3, data3 = next(generator)
    t4, data4 = next(generator)

    assert t4 == 1080000
    assert streamer.virtual_clock == 1080000

    elapsed_minutes = streamer.get_elapsed_time_minutes()
    # 1080000 - 1000000 = 80000 ms = 1.3333 perc
    assert np.isclose(elapsed_minutes, 80000 / 60000)
