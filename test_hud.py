import pandas as pd
from lightweight_charts import Chart

def test():
    chart = Chart(inner_width=1.0, inner_height=1.0)

    times = pd.date_range("2023-01-01", periods=10, freq="min")
    df = pd.DataFrame({"time": times, "open": 1, "high": 1.1, "low": 0.9, "close": 1})
    chart.set(df)

    line_long = chart.create_line(name="P_Long", color="green")

    # Ezzel elvileg lefut-e a set() Hiba nélkül?
    df_long = pd.DataFrame({"time": times, "P_Long": 0.0})
    line_long.set(df_long)
    print("SUCCESS SET")

    # 3. Update teszt pd.Series formátummal ahol a kulcs name maga a vonal név és az érték:
    # A forráskód alapján: series_datetime_format vár egy Series-t, de pontosan hogyan?
    new_time = times[-1] + pd.Timedelta(minutes=1)

    # Próbáljuk simán 'value'-val ha nem kér fixen P_Long-ot a dictben dict Series-ként
    s = pd.Series({'time': new_time, 'P_Long': 0.5})

    try:
        line_long.update(s)
        print("SUCCESS UPDATE WITH P_Long")
    except Exception as e:
        print("FAILED P_LONG:", e)

test()
