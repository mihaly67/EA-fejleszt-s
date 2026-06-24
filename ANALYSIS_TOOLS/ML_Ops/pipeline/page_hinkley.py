class PageHinkleyTest:
    """
    Page-Hinkley teszt a hirtelen statisztikai drift (koncepcióváltozás)
    detektálására a rekonstrukciós hibák áramlásában.
    A Gemini kutatás alapján ideális a brókeri manipulációs sokk felismeréséhez.
    """
    def __init__(self, delta: float = 0.005, threshold: float = 50.0, alpha: float = 0.9999):
        self.delta = delta      # Megengedett minimális változás (zaj)
        self.threshold = threshold # A riasztás küszöbértéke
        self.alpha = alpha      # Felejtési tényező a futó átlaghoz

        self.mean = 0.0
        self.sum = 0.0
        self.n = 0
        self.is_initialized = False

    def update(self, value: float) -> bool:
        """
        Új MSE érték hozzáadása a teszthez.
        Visszaadja a True-t, ha driftet (koncepcióváltozást) detektált.
        """
        if not self.is_initialized:
            self.mean = value
            self.n = 1
            self.is_initialized = True
            return False

        self.n += 1

        # Futó átlag frissítése (exponenciális simítással vagy egyszerűen)
        self.mean = self.mean + (value - self.mean) / self.n

        # Kumulatív eltérés számítása
        self.sum = self.sum + (value - self.mean - self.delta)

        # Kisebb, mint nulla eltérések vágása (Cusum jelleg)
        if self.sum < 0:
            self.sum = 0

        # Ha a kumulatív összeg meghaladja a küszöböt, az egy drift
        if self.sum > self.threshold:
            self._reset()
            return True

        return False

    def _reset(self):
        """Reseteli az állapotot egy talált drift után."""
        self.mean = 0.0
        self.sum = 0.0
        self.n = 0
        self.is_initialized = False
