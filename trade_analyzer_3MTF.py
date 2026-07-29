import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import sys

DATA_PATH = "data/exam_24h_volatile_3MTF.csv"
MODEL_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"
OUTPUT_CSV = "data/trade_analysis_report.csv"

def determine_trend(row):
    """
    Egyszerű trend meghatározás a makro indikátorok alapján.
    M15_RSI_14 > 55 -> Uptrend
    M15_RSI_14 < 45 -> Downtrend
    Egyébként -> Sideways
    """
    rsi = row['M15_RSI_14']
    if pd.isna(rsi):
        return 'Unknown'
    if rsi > 55:
        return 'Uptrend'
    elif rsi < 45:
        return 'Downtrend'
    else:
        return 'Sideways'

def main():
    print(f"Adatok betöltése: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True)

    ignore_cols = [
        'Start_Timestamp', 'End_Timestamp', 'Target_Label',
        'Open', 'High', 'Low', 'Close',
        'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value',
        '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close',
        'Bar_Time_Seconds', 'OBI_Raw',
        'P_Short', 'P_Noise', 'P_Long', 'Signal'
    ]
    features = [col for col in df.columns if col not in ignore_cols]

    X_test = df[features]
    y_true = df['Target_Label'].values
    if y_true.min() == -1:
        y_true = y_true + 1 # 0: Short, 1: Noise, 2: Long

    print(f"Modell betöltése: {MODEL_PATH}")
    try:
        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(X_test)
    except:
        model = lgb.Booster(model_file=MODEL_PATH)
        probs = model.predict(X_test)

    p_short = probs[:, 0]
    p_noise = probs[:, 1]
    p_long = probs[:, 2]

    # Elemezzük a nyers argmax döntéseket, hogy lássuk, mit tenne magától küszöbök nélkül
    preds_argmax = np.argmax(probs, axis=1)

    analysis_data = []

    for i in range(len(df)):
        signal = preds_argmax[i]

        # Csak az aktív (Long vagy Short) jeleket vizsgáljuk
        if signal == 0 or signal == 2:
            row = df.iloc[i]
            trend = determine_trend(row)
            actual_label = y_true[i]

            is_correct = (signal == actual_label)

            signal_name = 'Long' if signal == 2 else 'Short'
            actual_name = 'Long' if actual_label == 2 else ('Short' if actual_label == 0 else 'Noise')

            # Trend iránnyal megegyezik-e a kötés?
            with_trend = 'Yes' if (signal_name == 'Long' and trend == 'Uptrend') or (signal_name == 'Short' and trend == 'Downtrend') else 'No'
            if trend == 'Sideways' or trend == 'Unknown':
                with_trend = 'Neutral'

            analysis_data.append({
                'Index': i,
                'Start_Timestamp': row.get('Start_Timestamp', 'N/A'),
                'Close_Price': row.get('Close', np.nan),
                'Macro_Trend': trend,
                'Signal': signal_name,
                'Actual_Label': actual_name,
                'Is_Correct': is_correct,
                'With_Trend': with_trend,
                'P_Short': p_short[i],
                'P_Long': p_long[i],
                'P_Noise': p_noise[i]
            })

    res_df = pd.DataFrame(analysis_data)

    print("\n" + "="*60)
    print("📊 TRADE ANALYZER STATISZTIKA (Nyers Argmax)")
    print("="*60)

    total_trades = len(res_df)
    print(f"Összes aktív kötés (argmax alapján): {total_trades}")

    print("\n📉 Trend szerinti megoszlás:")
    trend_counts = res_df['Macro_Trend'].value_counts()
    for t, c in trend_counts.items():
        print(f"  {t}: {c} db ({(c/total_trades)*100:.1f}%)")

    print("\n🎯 Kötésirány Trend szerint:")
    for trend in ['Uptrend', 'Downtrend', 'Sideways']:
        trend_df = res_df[res_df['Macro_Trend'] == trend]
        if len(trend_df) > 0:
            longs = len(trend_df[trend_df['Signal'] == 'Long'])
            shorts = len(trend_df[trend_df['Signal'] == 'Short'])
            print(f"  {trend} -> Long: {longs}, Short: {shorts}")

    print("\n✅ Win Rate Trend Irányú vs Trend Elleni kötéseknél:")
    for wt in ['Yes', 'No', 'Neutral']:
        wt_df = res_df[res_df['With_Trend'] == wt]
        if len(wt_df) > 0:
            wr = wt_df['Is_Correct'].mean() * 100
            print(f"  Trenddel azonos ({wt}): {wr:.2f}% Win Rate ({len(wt_df)} kötés)")

    print("\n🧠 Átlagos Probabilitások Helytelen Kötéseknél (Hibaelemzés):")
    wrong_df = res_df[~res_df['Is_Correct']]
    if len(wrong_df) > 0:
        wrong_longs = wrong_df[wrong_df['Signal'] == 'Long']
        wrong_shorts = wrong_df[wrong_df['Signal'] == 'Short']

        if len(wrong_longs) > 0:
            print(f"  Hibás Longok -> Átlag P_Long: {wrong_longs['P_Long'].mean():.4f}, Átlag P_Short: {wrong_longs['P_Short'].mean():.4f}")
        if len(wrong_shorts) > 0:
            print(f"  Hibás Shortok -> Átlag P_Short: {wrong_shorts['P_Short'].mean():.4f}, Átlag P_Long: {wrong_shorts['P_Long'].mean():.4f}")

    res_df.to_csv(OUTPUT_CSV, index=False)
    print(f"\nRészletes CSV jelentés elmentve: {OUTPUT_CSV}")

if __name__ == "__main__":
    main()
