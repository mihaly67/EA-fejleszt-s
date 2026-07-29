import pandas as pd
import numpy as np
import lightgbm as lgb
import sys
import joblib
import json

def evaluate_exam(data_path, model_path, params_path):
    print(f"🔄 Vizsga Adatok betöltése: {data_path}")
    df = pd.read_csv(data_path).dropna().reset_index(drop=True)

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
    y_test = df['Target_Label'].values
    if y_test.min() == -1:
        y_test = y_test + 1

    with open(params_path, 'r') as f:
        best_params = json.load(f)

    threshold_short = best_params['threshold_short']
    threshold_long = best_params['threshold_long']
    max_noise = best_params['max_noise']

    print(f"Aszimmetrikus küszöbök -> Short: {threshold_short:.4f}, Long: {threshold_long:.4f}, Max Noise: {max_noise:.4f}")

    print(f"Modell betöltése: {model_path}")
    try:
        model = joblib.load(model_path)
        probs = model.predict_proba(X_test)
    except:
        model = lgb.Booster(model_file=model_path)
        probs = model.predict(X_test)

    p_short = probs[:, 0]
    p_noise = probs[:, 1]
    p_long = probs[:, 2]

    preds = np.ones_like(y_test)
    long_cond = (p_long > threshold_long) & (p_long > p_short) & (p_noise < max_noise)
    short_cond = (p_short > threshold_short) & (p_short > p_long) & (p_noise < max_noise)

    preds[long_cond] = 2
    preds[short_cond] = 0

    print("\n" + "="*50)
    print("🚀 ÉRTÉKELÉS ASZIMMETRIKUS KÜSZÖBÖKKEL")
    print("="*50)

    active_idx = np.where((preds == 0) | (preds == 2))[0]
    total_active = len(active_idx)

    start_t = pd.to_datetime(df['Start_Timestamp'].iloc[0], format='mixed', utc=True)
    end_t = pd.to_datetime(df['End_Timestamp'].iloc[-1], format='mixed', utc=True)
    days = (end_t - start_t).total_seconds() / 86400
    days = max(days, 1)

    print(f"⏱️ Vizsga időszak hossza: {days:.2f} nap")
    print(f"Valószínűség eloszlások - Noise: Min: {p_noise.min():.4f}, Max: {p_noise.max():.4f}, Átlag: {p_noise.mean():.4f}")

    if total_active > 0:
        y_test_active = y_test[active_idx]
        preds_active = preds[active_idx]

        correct = np.sum(preds_active == y_test_active)
        win_rate = (correct / total_active) * 100
        trades_per_day = total_active / days

        short_idx = np.where(preds_active == 0)[0]
        short_correct = np.sum(preds_active[short_idx] == y_test_active[short_idx])
        short_acc = (short_correct / len(short_idx) * 100) if len(short_idx) > 0 else 0

        long_idx = np.where(preds_active == 2)[0]
        long_correct = np.sum(preds_active[long_idx] == y_test_active[long_idx])
        long_acc = (long_correct / len(long_idx) * 100) if len(long_idx) > 0 else 0

        print(f"🎯 Modell által generált aktív jelek (összesen): {total_active} db")
        print(f"📈 Napi Átlagos Kötésszám: {trades_per_day:.2f} / nap")
        print(f"✅ ASZIMMETRIKUS WIN RATE: {win_rate:.2f}%")
        print(f"   📉 Short pontosság: {short_acc:.2f}% ({len(short_idx)} jelből)")
        print(f"   📈 Long pontosság:  {long_acc:.2f}% ({len(long_idx)} jelből)")

    else:
        print("❌ A modell nem adott aktív jelet a vizsga teszthalmazon ezekkel a küszöbökkel.")

if __name__ == '__main__':
    evaluate_exam(sys.argv[1], sys.argv[2], sys.argv[3])
