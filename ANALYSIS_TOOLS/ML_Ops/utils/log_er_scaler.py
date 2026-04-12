import numpy as np

class LogERScaler:
    """
    Scale-Dependent Log-Efficiency Ratio (LogER) Lookup Table és Normalizátor.

    Probléma:
    A Fractional Brownian Motion (FBM) "Optikai Csalódás" miatt a nyers LogER
    matematikailag függ a megfigyelési ablak hosszától (N). Ha dinamikusan váltogatjuk
    az ablakméretet (ATDP), a Welford Scaler és a HMM torz, fals anomáliákat érzékelne,
    mert az N=15-ös és N=150-es ablak LogER alapértelmezett "zaja" eltérő dimenziójú.

    Megoldás (O(1) Komplexitás):
    Egy statikusan előre kalkulált Lookup Table (Skála-Faktor Mátrix), amely
    dinamikusan normalizálja a nyers ER értéket a pillanatnyi ablakmérethez viszonyítva.
    """

    def __init__(self, base_n=15, max_n=500, hurst_exponent=0.5):
        """
        :param base_n: A referencia ablakméret (általában a minimum, pl. 15), amelyhez viszonyítunk.
        :param max_n: A Lookup Table maximális mérete (hogy a memóriafoglalás statikus maradjon).
        :param hurst_exponent: A piac fraktális dimenziója (0.5 = Random Walk / Hatékony Piac).
        """
        self.base_n = base_n
        self.max_n = max_n
        self.hurst = hurst_exponent

        # O(1) Lookup Table allokálása
        self.scale_factors = np.ones(max_n + 1, dtype=np.float64)
        self._precompute_lookup_table()

    def _precompute_lookup_table(self):
        """
        Kiszámolja a normalizációs faktorokat az összes lehetséges N értékre.
        A képlet a Hurst exponensből származik: Várható Távolság ~ N^H
        Így a korrekciós faktor: (base_n / N)^H
        """
        # N=0 és N=1 esetében a LogER értelmezhetetlen, marad 1.0 (semleges szorzó)
        for n in range(2, self.max_n + 1):
            # A korrekció úgy van beállítva, hogy a base_n ablak LogER-je
            # pontosan azonos súlyú maradjon a nagyobb ablakokhoz képest.
            factor = (self.base_n / n) ** self.hurst
            self.scale_factors[n] = factor

    def normalize(self, raw_er: float, current_n: int) -> float:
        """
        O(1) sebességű normalizáció a Lookup Table alapján.
        :param raw_er: A nyers Log-Efficiency Ratio (Kaufman ER).
        :param current_n: A jelenlegi ablak hossza, amiből a raw_er kiszámolásra került.
        """
        if current_n <= 1:
            return 0.0

        # Határérték védelem (Array Out of Bounds ellen)
        safe_n = min(int(current_n), self.max_n)

        # Vektorizált, hardveres sebességű szorzás
        normalized_er = raw_er * self.scale_factors[safe_n]

        return normalized_er

    def normalize_vector(self, raw_er_array: np.ndarray, current_n: int) -> np.ndarray:
        """
        Tömbösített normalizáció (Vectorized Broadcasting) abban az esetben, ha
        a jövőben több devizapár LogER-jét számoljuk egyszerre.
        """
        if current_n <= 1:
            return np.zeros_like(raw_er_array)

        safe_n = min(int(current_n), self.max_n)
        return raw_er_array * self.scale_factors[safe_n]
