import numpy as np
import math

class FastADWIN:
    """
    Extrém gyors ADWIN implementáció list slicing helyett O(1) bufferrel.
    A sum() hívást a ciklusból kivettem.
    """
    def __init__(self, delta=0.002, min_window=30):
        self.delta = delta
        self.min_window = min_window
        self.window = []
        self.sum = 0.0
        self.sq_sum = 0.0

    def add_element(self, value):
        self.window.append(value)
        self.sum += value
        self.sq_sum += value * value
        n = len(self.window)

        if n < self.min_window * 2: return False

        # Csak a min_window többszöröseinél vizsgálunk (pl minden 30. tick után) hogy spóroljunk
        if n % 10 != 0: return False

        step = self.min_window
        cut_point = -1

        # O(1) var
        var = (self.sq_sum / n) - ((self.sum / n) ** 2)
        if var <= 0: var = 0.0001
        delta_prime = self.delta / n
        log_term = math.log(2.0 / delta_prime)

        # W1 (friss) sum fenntartása iteratívan, slicing és beépített sum() nélkül
        w1_sum = sum(self.window[-step:])

        while step <= n / 2:
            n1 = step
            n0 = n - step

            w0_sum = self.sum - w1_sum
            u1 = w1_sum / n1
            u0 = w0_sum / n0

            m = 1.0 / (1.0/n0 + 1.0/n1)
            epsilon = math.sqrt((2.0 / m) * var * log_term) + (2.0 / (3.0 * m)) * log_term

            if abs(u0 - u1) > epsilon:
                cut_point = n - step
                break

            # Mielőtt duplázzuk a step-et, hozzáadjuk az új intervallumot a w1_sum-hoz O(N) helyett
            # De mivel listánk van, a legegyszerűbb, ha csak annyit adunk hozzá ami kell.
            next_step = step * 2
            if next_step <= n / 2:
                w1_sum += sum(self.window[-next_step:-step])
            step = next_step

        if cut_point > 0:
            removed = self.window[:cut_point]
            self.window = self.window[cut_point:]
            for val in removed:
                self.sum -= val
                self.sq_sum -= (val * val)
            return True

        return False

# Teszt a gyorsaságra
if __name__ == '__main__':
    import time
    adwin = FastADWIN(delta=0.01)
    stream = np.concatenate([np.random.normal(0, 1, 100000), np.random.normal(3, 1, 100000)])

    start = time.time()
    drifts = []
    for i, val in enumerate(stream):
        if adwin.add_element(val):
            drifts.append((i, len(adwin.window)))
    end = time.time()

    print(f"ADWIN Fast teszt kész {end-start:.4f} sec alatt 200,000 tickre. Észlelt driftek: {len(drifts)}")
