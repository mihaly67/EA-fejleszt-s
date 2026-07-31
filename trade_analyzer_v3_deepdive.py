import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import json

DATA_PATH = "data/exam_24h_volatile_3MTF.csv"
MODEL_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"
PARAMS_PATH = "models/optuna_strict_thresholds.json"
OUTPUT_TXT = "data/deepdive_report.txt"

def determine_trend(rsi):
    if pd.isna(rsi): return 'Unknown'
    if rsi > 55: return 'Uptrend'
    elif rsi < 45: return 'Downtrend'
    else: return 'Sideways'

def main():
    with open(OUTPUT_TXT, 'w') as f_out:
        def log_print(msg):
            print(msg)
            f_out.write(msg + "\n")

        log_print("=== 🕵️ AGENT DEEP DIVE ANALYZER V3 ===")

        df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True)
        ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
        features = [col for col in df.columns if col not in ignore_cols]

        X_test = df[features]
        y_true = df['Target_Label'].values
        if y_true.min() == -1: y_true = y_true + 1 # 0: Short, 1: Noise, 2: Long

        df['Macro_Trend'] = df['M15_RSI_14'].apply(determine_trend)

        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(X_test)

        df['P_Short'] = probs[:, 0]
        df['P_Noise'] = probs[:, 1]
        df['P_Long'] = probs[:, 2]
        df['Actual_Target'] = y_true

        with open(PARAMS_PATH, 'r') as f:
            p = json.load(f)

        df['Thr_Long'] = np.where(df['Macro_Trend'] == 'Uptrend', p['up_thr_long'], np.where(df['Macro_Trend'] == 'Downtrend', p['down_thr_long'], p['side_thr_long']))
        df['Thr_Short'] = np.where(df['Macro_Trend'] == 'Uptrend', p['up_thr_short'], np.where(df['Macro_Trend'] == 'Downtrend', p['down_thr_short'], p['side_thr_short']))
        df['Max_Noise'] = np.where(df['Macro_Trend'] == 'Uptrend', p['up_max_noise'], np.where(df['Macro_Trend'] == 'Downtrend', p['down_max_noise'], p['side_max_noise']))

        preds = np.ones(len(df))
        long_cond = (df['P_Long'] > df['Thr_Long']) & (df['P_Noise'] < df['Max_Noise'])
        short_cond = (df['P_Short'] > df['Thr_Short']) & (df['P_Noise'] < df['Max_Noise'])

        preds[long_cond] = 2
        preds[short_cond] = 0
        df['Signal'] = preds

        # Trend blokkok létrehozása (Sequence Analysis)
        blocks = []
        current_trend = df['Macro_Trend'].iloc[0]
        start_idx = 0

        for i in range(1, len(df)):
            if df['Macro_Trend'].iloc[i] != current_trend:
                blocks.append((start_idx, i - 1, current_trend))
                current_trend = df['Macro_Trend'].iloc[i]
                start_idx = i
        blocks.append((start_idx, len(df) - 1, current_trend))

        log_print(f"Total Trend Blocks Found: {len(blocks)}")

        # Elemzés: Hosszú vs Lomha trendek
        long_trends = [b for b in blocks if (b[1] - b[0] > 30) and b[2] != 'Sideways']
        short_trends = [b for b in blocks if (b[1] - b[0] <= 15) and b[2] != 'Sideways']

        log_print(f"\n--- 1. HOSSZÚ / INTENZÍV TRENDEK ELEMZÉSE ({len(long_trends)} db) ---")
        for start, end, trend in long_trends[:3]: # Csak 3-at mutatunk részletesen a logban
            block_df = df.iloc[start:end+1]
            length = len(block_df)
            active_signals = (block_df['Signal'] != 1).sum()
            trend_signals = (block_df['Signal'] == (2 if trend=='Uptrend' else 0)).sum()
            contra_signals = (block_df['Signal'] == (0 if trend=='Uptrend' else 2)).sum()

            log_print(f"Block [{start}-{end}] | {trend} | Length: {length} bars")
            log_print(f"  -> Activity: {active_signals}/{length} ({active_signals/length*100:.1f}%)")
            log_print(f"  -> Trend irányú belépés: {trend_signals}, Kontratrend: {contra_signals}")

        log_print(f"\n--- 2. LOMHA / RÖVID TRENDEK ELEMZÉSE ({len(short_trends)} db) ---")
        for start, end, trend in short_trends[:3]:
            block_df = df.iloc[start:end+1]
            length = len(block_df)
            active_signals = (block_df['Signal'] != 1).sum()
            trend_signals = (block_df['Signal'] == (2 if trend=='Uptrend' else 0)).sum()
            contra_signals = (block_df['Signal'] == (0 if trend=='Uptrend' else 2)).sum()

            log_print(f"Block [{start}-{end}] | {trend} | Length: {length} bars")
            log_print(f"  -> Activity: {active_signals}/{length} ({active_signals/length*100:.1f}%)")
            log_print(f"  -> Trend irányú belépés: {trend_signals}, Kontratrend: {contra_signals}")

        log_print("\n--- 3. OKNYOMOZÁS: BÁRRÓL-BÁRRA (Miért nincs belépés?) ---")
        # Keresünk egy olyan szakaszt, ami egyértelmű trend, a gép mégis 'Noise'-ot (1) adott
        # miközben az igazi label trendirányú lett volna.

        investigated = 0
        for start, end, trend in long_trends:
            if investigated >= 10: break

            block_df = df.iloc[start:end+1]
            # Olyan bárokat keresünk a hosszú trenden belül, amit kihagyott (Signal=1), de az Actul_Label trend irányú volt
            target_label = 2 if trend == 'Uptrend' else 0
            missed_df = block_df[(block_df['Signal'] == 1) & (block_df['Actual_Target'] == target_label)]

            for idx, row in missed_df.head(2).iterrows(): # Blokkonként max 2 példa
                investigated += 1
                log_print(f"\n🔍 Bár elemzés (Index: {idx}, {trend})")
                log_print(f"  Valós Irány (Actual): {'LONG' if target_label==2 else 'SHORT'}")
                log_print(f"  Gép Jelzése: Nincs (HOLD / 1)")
                log_print(f"  P_Long:  {row['P_Long']:.4f} (Küszöb: {row['Thr_Long']:.4f})")
                log_print(f"  P_Short: {row['P_Short']:.4f} (Küszöb: {row['Thr_Short']:.4f})")
                log_print(f"  P_Noise: {row['P_Noise']:.4f} (Zaj limit: {row['Max_Noise']:.4f})")

                # Diagnose
                if row['P_Noise'] >= row['Max_Noise']:
                    log_print("  ❌ Döntés oka: A Zajszint (P_Noise) túllépte a megengedett Max_Noise korlátot!")
                else:
                    if trend == 'Uptrend':
                        diff = row['P_Long'] - row['Thr_Long']
                        log_print(f"  ❌ Döntés oka: P_Long alacsonyabb volt a küszöbnél {row['Thr_Long'] - row['P_Long']:.4f} ponttal.")
                    else:
                        diff = row['P_Short'] - row['Thr_Short']
                        log_print(f"  ❌ Döntés oka: P_Short alacsonyabb volt a küszöbnél {row['Thr_Short'] - row['P_Short']:.4f} ponttal.")

if __name__ == "__main__":
    main()
