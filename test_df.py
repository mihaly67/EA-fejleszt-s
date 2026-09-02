import pandas as pd
from lightweight_charts import Chart
import time

def main():
    chart = Chart(inner_width=1.0, inner_height=1.0)
    times = pd.date_range('2024-01-01', periods=10, freq='min')

    # Passing raw datetime objects (NOT strings)
    df = pd.DataFrame({'time': times, 'open': 100, 'high': 101, 'low': 99, 'close': 100})

    chart.set(df)

    line_long = chart.create_line(name="P_Long", color="#00ff00", width=2)
    df_long = pd.DataFrame({'time': df['time'], 'P_Long': 0.0})

    line_long.set(df_long)

    print("Set completed!")

main()
