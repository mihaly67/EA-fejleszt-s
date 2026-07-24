import pandas as pd
import numpy as np
import lightgbm as lgb
import os
import sys

def analyze_signals(data_path, model_path):
    print(f"🔄 Adatok betöltése: {data_path}")
    df = pd.read_csv(data_path).dropna()

    # Időbeli elemzéshez betöltjük az időbélyegeket is
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])
    df['Bar_Time_Seconds'] = (df['End_Timestamp'] - df['Start_Timestamp']).dt.total_seconds()

    from hud_logic_prep import get_dynamic_features
    features = get_dynamic_features(df)

    X = df[features].values

    split_idx = int(len(df) * 0.8)
    X_test = X[split_idx:]
    time_test = df['Bar_Time_Seconds'].values[split_idx:]

    print(f"🔄 Modell betöltése: {model_path}")
    bst = lgb.Booster(model_file=model_path)
    probs = bst.predict(X_test)
    preds = np.argmax(probs, axis=1) # 0: Short, 1: Zaj, 2: Long

    # Eltolás emberi formátumra: -1, 0, 1
    signals = preds - 1

    avg_bar_time = np.mean(time_test)
    print(f"\n⏱️  Egy Dollar Bar átlagos képződési ideje OOS szakaszon: {avg_bar_time:.2f} másodperc")

    # Blokkok / Szériák keresése
    current_signal = None
    streak_lengths = []
    whipsaws = 0
    total_active_signals = 0

    current_streak = 0

    for i, sig in enumerate(signals):
        if sig != 0:
            total_active_signals += 1

        if sig != current_signal:
            # Váltás történt
            if current_signal is not None and current_signal != 0:
                streak_lengths.append(current_streak)

                # Ha az előző jel 1 volt és most -1 (vagy fordítva) 0 (Zaj) nélkül, az Whipsaw
                if sig != 0 and current_signal == -sig:
                    whipsaws += 1

            current_signal = sig
            current_streak = 1
        else:
            # Ugyanaz a jel folytatódik
            current_streak += 1

    # Az utolsó streak lezárása
    if current_signal is not None and current_signal != 0:
        streak_lengths.append(current_streak)

    avg_streak = np.mean(streak_lengths) if streak_lengths else 0
    max_streak = np.max(streak_lengths) if streak_lengths else 0

    print("\n📊 --- Szignál Stabilitás Elemzés (LightGBM) ---")
    print(f"Összes kiadott aktív (Long/Short) jel száma: {total_active_signals}")
    print(f"Átlagosan hány Dollar Barig tartja az irányt egyhuzamban: {avg_streak:.1f} bar")
    print(f"Becsült átlagos időtartam (Átlag Streak * Átlag Bar idő): {(avg_streak * avg_bar_time):.1f} másodperc")
    print(f"Leghosszabb egybefüggő trend tartás: {max_streak} bar ({(max_streak * avg_bar_time / 60):.1f} perc)")

    # A whipsaw azt jelenti, hány százaléka a váltásoknak azonnali (-1 -> 1), nem pedig (-1 -> 0 -> 1)
    # Ahol 0 = Zaj, azaz kivárás a piacon.
    total_streaks = len(streak_lengths)
    whipsaw_rate = (whipsaws / total_streaks * 100) if total_streaks > 0 else 0

    print(f"\n⚠️  Whipsaw (Közvetlen irányváltás Zaj zóna nélkül): {whipsaws} db")
    print(f"Whipsaw aránya az összes trendváltásból: {whipsaw_rate:.2f}%")

if __name__ == '__main__':
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv'
    model_path = '/home/misi/Merkava_ML_Ops/models/lgbm_copilot_model.txt'

    if len(sys.argv) > 2:
        data_path = sys.argv[1]
        model_path = sys.argv[2]

    analyze_signals(data_path, model_path)
