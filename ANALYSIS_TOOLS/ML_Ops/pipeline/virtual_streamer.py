import pandas as pd
import numpy as np
import logging

logger = logging.getLogger(__name__)

class VirtualClockStreamer:
    """
    Soronként (tick-enként) adagolja a CSV adatait a 'TimeMsc' vagy 'TickMSC'
    időbélyegek alapján, szimulálva az élő MT5 ZMQ kapcsolatot.

    A belső 'virtual_clock' a legutóbb kiadott tick időbélyegét tárolja.
    Ez garantálja, hogy a feldolgozó (pl. kalibráló hurok) pontosan tudja
    számolni az eltelt virtuális perceket a valós CPU idő kivárása nélkül.
    """

    def __init__(self, filepath: str):
        self.filepath = filepath
        self.virtual_clock = None
        self.start_time = None
        self.total_rows = 0
        self._load_data()

    def _load_data(self):
        """Betölti a CSV-t, és megkeresi a milliszekundum alapú időbélyeg oszlopot."""
        logger.info(f"[Virtual Streamer] Adatok betöltése: {self.filepath}")
        self.df = pd.read_csv(self.filepath)
        self.total_rows = len(self.df)

        # Oszlopnév azonosítás (támogatjuk mindkét elnevezést a legacy kompatibilitás miatt)
        self.time_col = 'TickMSC' if 'TickMSC' in self.df.columns else 'TimeMsc'

        if self.time_col not in self.df.columns:
            raise ValueError(f"Nem találtam '{self.time_col}' oszlopot a CSV-ben! A virtuális idő szimulációhoz kötelező.")

        # Biztosítjuk, hogy az időbélyegek sorrendben vannak
        self.df = self.df.sort_values(by=self.time_col).reset_index(drop=True)
        self.start_time = self.df[self.time_col].iloc[0]
        self.virtual_clock = self.start_time

        logger.info(f"[Virtual Streamer] Összes tick: {self.total_rows}. Virtuális kezdőidő: {self.start_time}")

    def stream_ticks(self):
        """
        Generátor (yield), ami soronként adja vissza az adatokat, és frissíti a virtuális órát.
        Visszaadja: (virtual_clock_ms, sor_adatai_dict_kent)
        """
        for index, row in self.df.iterrows():
            # Virtuális óra frissítése az aktuális tick időbélyegére
            self.virtual_clock = row[self.time_col]

            # A sor adatait (feature-öket) szótárként (dict) adjuk vissza
            # hogy a RollingLSTM könnyen kezelhesse őket.
            yield self.virtual_clock, row.to_dict()

    def get_elapsed_time_minutes(self):
        """Visszaadja a szimuláció kezdete óta eltelt virtuális perceket."""
        if self.virtual_clock is None or self.start_time is None:
            return 0.0
        # ms -> sec -> min
        return (self.virtual_clock - self.start_time) / (1000 * 60)
