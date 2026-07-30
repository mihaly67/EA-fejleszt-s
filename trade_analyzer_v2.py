import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import json
import sys

DATA_PATH = "data/exam_24h_volatile_3MTF.csv"
MODEL_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"
PARAMS_PATH = "models/optuna_regime_params_3MTF_v3.json"
OUTPUT_CSV = "data/trade_analysis_report_v2.csv"

def determine_trend(rsi):
    if pd.isna(rsi): return 'Unknown'
    if rsi > 55: return 'Uptrend'
    elif rsi < 45: return 'Downtrend'
    else: return 'Sideways'

def main():
    print(f"Adatok betöltése: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]

    X_test = df[features]
    y_true = df['Target_Label'].values
    if y_true.min() == -1: y_true += 1 # 0: Short, 1: Noise, 2: Long

    df['Macro_Trend'] = df['M15_RSI_14'].apply(determine_trend)

    print(f"Modell betöltése: {MODEL_PATH}")
    try:
        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(X_test)
    except:
        model = lgb.Booster(model_file=MODEL_PATH)
        probs = model.predict(X_test)

    df['P_Short'] = probs[:, 0]
    df['P_Noise'] = probs[:, 1]
    df['P_Long'] = probs[:, 2]

    with open(PARAMS_PATH, 'r') as f:
        p = json.load(f)

    # Dinamikus küszöbök generálása
    df['Thr_Long'] = np.where(df['Macro_Trend'] == 'Uptrend', p['up_thr_long'],
                     np.where(df['Macro_Trend'] == 'Downtrend', p['down_thr_long'], p['side_thr_long']))

    df['Thr_Short'] = np.where(df['Macro_Trend'] == 'Uptrend', p['up_thr_short'],
                      np.where(df['Macro_Trend'] == 'Downtrend', p['down_thr_short'], p['side_thr_short']))

    df['Max_Noise'] = np.where(df['Macro_Trend'] == 'Uptrend', p['up_max_noise'],
                      np.where(df['Macro_Trend'] == 'Downtrend', p['down_max_noise'], p['side_max_noise']))

    # Kiértékelés az aktuális paraméterekkel
    preds = np.ones(len(df))
    long_cond = (df['P_Long'] > df['Thr_Long']) & (df['P_Long'] > df['P_Short']) & (df['P_Noise'] < df['Max_Noise'])
    short_cond = (df['P_Short'] > df['Thr_Short']) & (df['P_Short'] > df['P_Long']) & (df['P_Noise'] < df['Max_Noise'])

    preds[long_cond] = 2
    preds[short_cond] = 0
    df['Signal'] = preds

    # Elemzés
    active_mask = (df['Signal'] == 0) | (df['Signal'] == 2)
    df['Is_Correct'] = df['Signal'] == y_true

    # Kontratrend kötések (Uptrendben Shortol, vagy Downtrendben Longol)
    df['Is_Counter_Trend'] = False
    df.loc[(df['Macro_Trend'] == 'Uptrend') & (df['Signal'] == 0), 'Is_Counter_Trend'] = True
    df.loc[(df['Macro_Trend'] == 'Downtrend') & (df['Signal'] == 2), 'Is_Counter_Trend'] = True

    # Kihagyott szakaszok: Amikor van erős trend, és az igazi címke trendirányú, de a gép nem lépett be
    df['Missed_Opportunity'] = False

    # Uptrendben várunk egy Longot (ha az igazi label is Long volt), de a Signal Noise (1) maradt
    missed_up = (df['Macro_Trend'] == 'Uptrend') & (y_true == 2) & (df['Signal'] == 1)
    # Downtrendben várunk egy Shortot (ha az igazi label is Short volt), de a Signal Noise (1) maradt
    missed_down = (df['Macro_Trend'] == 'Downtrend') & (y_true == 0) & (df['Signal'] == 1)

    df.loc[missed_up | missed_down, 'Missed_Opportunity'] = True

    # Statisztika kinyomtatása
    print("\n" + "="*60)
    print("📊 ADVANCED TRADE ANALYZER STATISZTIKA")
    print("="*60)

    total_active = active_mask.sum()
    win_rate = df[active_mask]['Is_Correct'].mean() * 100 if total_active > 0 else 0
    print(f"✅ Összes aktív kötés: {total_active} db (Win Rate: {win_rate:.2f}%)")

    counter_trend_count = df['Is_Counter_Trend'].sum()
    print(f"🚨 KONTRATREND (Veszélyes) Kötések: {counter_trend_count} db ({(counter_trend_count/total_active*100):.1f}%)")

    missed_count = df['Missed_Opportunity'].sum()
    print(f"📉 KIHAGYOTT TREND SZAKASZOK (Missed): {missed_count} db")

    # A kihagyott szakaszok okai
    missed_df = df[df['Missed_Opportunity']].copy()
    if len(missed_df) > 0:
        # Okok elemzése:
        # 1. Túl magas Noise
        noise_blocked = missed_df[missed_df['P_Noise'] >= missed_df['Max_Noise']]
        # 2. Nem érte el az irányított Thr-t
        thr_blocked = missed_df[missed_df['P_Noise'] < missed_df['Max_Noise']] # A noise jó lett volna, de a P_X kevés volt

        print(f"\nMiért hagyta ki a trendet a gép? (Átlag értékek a kihagyott helyeken)")
        print(f"  - Noise miatt blokkolva: {len(noise_blocked)} db")
        if len(noise_blocked) > 0:
            print(f"      (Átlag P_Noise: {noise_blocked['P_Noise'].mean():.4f}, Max Noise Thr: {noise_blocked['Max_Noise'].mean():.4f})")

        print(f"  - Túl magas Irányított Küszöb miatt blokkolva: {len(thr_blocked)} db")
        if len(thr_blocked) > 0:
            # Uptrend missed (Longot vártunk)
            up_thr = thr_blocked[thr_blocked['Macro_Trend'] == 'Uptrend']
            if len(up_thr) > 0:
                print(f"      Uptrendben -> Átlag P_Long: {up_thr['P_Long'].mean():.4f} (Elvárt küszöb: {up_thr['Thr_Long'].mean():.4f})")
            # Downtrend missed (Shortot vártunk)
            down_thr = thr_blocked[thr_blocked['Macro_Trend'] == 'Downtrend']
            if len(down_thr) > 0:
                print(f"      Downtrendben -> Átlag P_Short: {down_thr['P_Short'].mean():.4f} (Elvárt küszöb: {down_thr['Thr_Short'].mean():.4f})")

    df.to_csv(OUTPUT_CSV, index=False)
    print(f"\nRészletes jelentés elmentve: {OUTPUT_CSV}")

if __name__ == "__main__":
    main()
