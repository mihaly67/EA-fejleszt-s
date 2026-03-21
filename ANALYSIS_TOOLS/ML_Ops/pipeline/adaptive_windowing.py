import numpy as np

def calculate_kaufman_efficiency_ratio(prices: np.ndarray, period: int = 10) -> float:
    """
    Kiszámítja a Kaufman Efficiency Ratio-t (ER).
    ER = Irány (Direction) / Volatilitás (Volatility)
    Értéke 0 (Zajos, oldalazó piac) és 1.0 (Erős trend) között mozog.

    Args:
        prices: Az árak (pl. Bid) numpy array formátumban.
        period: A visszatekintési periódus hossza.
    Returns:
        float: Az Efficiency Ratio. Ha nincs elég adat, 0.5-t ad vissza.
    """
    if len(prices) <= period:
        return 0.5  # Semleges visszatérés, ha nincs elég adat

    # Az árfolyam teljes (nettó) elmozdulása a periódus alatt
    change = abs(prices[-1] - prices[-(period + 1)])

    # Az egyedi (bruttó) lépések abszolút összege
    diffs = np.abs(np.diff(prices[-(period + 1):]))
    volatility = np.sum(diffs)

    if volatility == 0:
        return 0.0 # Nincs mozgás, döglött a piac

    return float(change / volatility)

def get_optimal_sequence_length(er: float) -> int:
    """
    A Kaufman Efficiency Ratio (ER) alapján meghatározza az optimális
    LSTM ablakméretet (Sequence Length / Emlékezet) a Gemini kutatás alapján.

    Fordított korreláció (A felismert paradigmaváltás):
    - Alacsony ER (Pangó, zajos piac) -> Nagyobb ablakméret (120-150) a kontextusért.
    - Magas ER (Trendelő, pörgős piac) -> Kisebb ablakméret (40-60) a gyors reakcióért.
    """
    # Heurisztikus leképezés a táblázat alapján
    if er < 0.2:
        return 150 # Konszolidáció, sávosodás, nagyon zajos
    elif er < 0.4:
        return 120 # Átmeneti, alacsony momentum
    elif er < 0.6:
        return 80  # Átlagos, aktív piac
    elif er < 0.8:
        return 50  # Erős trend
    else:
        return 40  # Breakout, Híresemény (nagyon magas volatilitás)
