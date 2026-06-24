import numpy as np

class O1RingBuffer:
    """
    O(1) Komplexitású Statikus Numpy RingBuffer a Tick Adatokhoz.
    Kizárja a Python listák 'append' és 'pop' memóriaugrásait,
    így a VPS-en (és MT5 integrációban) nem okoz latency tüskéket.

    Támogatja a Dinamikus Szeletelést (Slicing) az Adaptív Tick Sűrűség
    Protokollhoz (ATDP) újraallokáció nélkül.
    """

    def __init__(self, capacity: int, dimensions: int = 1):
        """
        :param capacity: A RingBuffer maximális befogadóképessége (pl. 1000 tick).
        :param dimensions: Az adatsor dimenziói (pl. 1 a nyers árhoz, 3 a HMM observation térhez).
        """
        self.capacity = capacity
        self.dimensions = dimensions

        # Statikus előfoglalás (A memória csak egyszer, az initkor allokálódik)
        if dimensions == 1:
            self.buffer = np.zeros(capacity, dtype=np.float64)
        else:
            self.buffer = np.zeros((capacity, dimensions), dtype=np.float64)

        self.index = 0
        self.count = 0

    def push(self, item):
        """O(1) sebességű betöltés a pufferbe."""
        self.buffer[self.index] = item
        self.index = (self.index + 1) % self.capacity
        self.count = min(self.count + 1, self.capacity)

    def get_slice(self, n: int):
        """
        Dinamikus szeletelés másolás és memória allokáció nélkül (View / Advanced Indexing).
        Visszaadja a legutolsó `n` elemet időrendi sorrendben (legrégebbitől a legújabbig).

        :param n: A kívánt ablakméret (Window Size) - tipikusan az ATDP által meghatározva.
        """
        if n <= 0:
            return np.array([])

        n = min(n, self.count)

        # Ha nincs még elég elem
        if n == 0:
            if self.dimensions == 1:
                return np.zeros(0)
            return np.zeros((0, self.dimensions))

        # Határok kiszámítása a körkörös elrendezésben
        start_idx = (self.index - n) % self.capacity

        # Ha a szelet nem lóg túl a buffer végén
        if start_idx < self.index:
            return self.buffer[start_idx:self.index]
        # Ha túlnyúlik a végen és átfordul az elejére
        else:
            if self.dimensions == 1:
                return np.concatenate((self.buffer[start_idx:], self.buffer[:self.index]))
            else:
                return np.vstack((self.buffer[start_idx:], self.buffer[:self.index]))

    def get_all(self):
        """Visszaadja az összes eddig betöltött elemet időrendben."""
        return self.get_slice(self.count)

    def is_full(self) -> bool:
        return self.count == self.capacity

    def clear(self):
        """Kereskedési fázis váltásakor vagy reseteléskor hasznos."""
        self.index = 0
        self.count = 0

    def get_current_density(self, time_buffer, time_window_ms=3000):
        """
        Visszaadja, hány tick történt az elmúlt 'time_window_ms' alatt.
        :param time_buffer: Egy O1RingBuffer példány, ami a TickMsc-t tárolja.
        :param time_window_ms: A fizikai ablak (pl. 3000 ms = 3 másodperc).
        """
        if time_buffer.count < 2:
            return time_buffer.count

        times = time_buffer.get_all()
        last_time = times[-1]
        threshold_time = last_time - time_window_ms

        # Hány tick van a threshold_time és last_time között
        # Mivel a times időrendben van, kereshetünk benne hatékonyan
        # (Nagy buffer esetén np.searchsorted lenne az igazi O(log N), de kis méretnél ez is jó)
        idx = np.searchsorted(times, threshold_time)
        return len(times) - idx
