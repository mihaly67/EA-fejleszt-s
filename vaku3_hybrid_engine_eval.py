import pandas as pd
import numpy as np
import logging
import os
import joblib

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class VakuHybridEngine:
    def __init__(self, macro_timeframe_min=5, hmm_risk_threshold=30.0, macro_er_threshold=0.3):
        self.macro_timeframe = f"{macro_timeframe_min}min"
        self.hmm_risk_threshold = hmm_risk_threshold
        self.macro_er_threshold = macro_er_threshold

    def calculate_macro_er(self, series):
        """Kiszámolja a Kaufman Efficiency Ratio-t a zárt gyertyákon."""
        if len(series) < 2:
            return 0.0
        net_move = abs(series.iloc[-1] - series.iloc[0])
        gross_move = np.sum(np.abs(np.diff(series)))
        if gross_move == 0:
            return 0.0
        return net_move / gross_move

    def process_hybrid_matrix(self, df):
        logger.info(f"🔄 Hibrid Feldolgozás Indítása (Makro: {self.macro_timeframe}, Mikro: Tick)")
        
        # 1. Időbélyeg konvertálása, hogy pandas resample-t tudjunk használni
        if 'TimeMsc' not in df.columns and 'TickMSC' not in df.columns:
            logger.error("Nincs megfelelő időbélyeg oszlop.")
            return None
            
        time_col = 'TimeMsc' if 'TimeMsc' in df.columns else 'TickMSC'
        df['Datetime'] = pd.to_datetime(df[time_col], unit='ms')
        df.set_index('Datetime', inplace=True)
        df.sort_index(inplace=True)

        # Átlagár kiszámolása
        if 'Ask' in df.columns and 'Bid' in df.columns:
            df['Price'] = (df['Ask'] + df['Bid']) / 2.0
        elif 'Last' in df.columns:
            df['Price'] = df['Last']
        else:
            df['Price'] = df.iloc[:, 1] # Fallback a második oszlopra
            
        # 2. MAKRO ABLAK: Zárt gyertyák generálása
        # Resample OHLC
        ohlc = df['Price'].resample(self.macro_timeframe).ohlc()
        
        # Makro Trend/ER számolás: Az elmúlt 5 gyertya (pl. 25 perc) alapján
        ohlc['Macro_ER'] = ohlc['close'].rolling(window=5).apply(self.calculate_macro_er, raw=False)
        ohlc['Macro_ER'] = ohlc['Macro_ER'].fillna(0)
        
        # 3. MIKRO ABLAK: A HMM Kockázat már benne van a CSV-ben (Theater_Risk_Pct) a vaku3_offline_validator_local_final.py alapján
        # Visszaillesztjük a Makro értékeket a tick szintű DataFrame-be a forward fill (ffill) módszerrel
        
        # DataFrame újrainxedálás a merge miatt
        df.reset_index(inplace=True)
        ohlc.reset_index(inplace=True)
        
        # Összefűzés asof merge segítségével (Minden tick megkapja az előzőleg lezárt makro gyertya ER értékét)
        hybrid_df = pd.merge_asof(df, ohlc[['Datetime', 'Macro_ER']], on='Datetime', direction='backward')
        
        # 4. HIBRID DÖNTÉSI MÁTRIX ALKALMAZÁSA
        # Szabályok:
        # - Ha Macro_ER > threshold ÉS Theater_Risk_Pct < threshold => GREEN
        # - Ha Macro_ER > threshold ÉS Theater_Risk_Pct >= threshold => YELLOW
        # - Ha Macro_ER <= threshold => RED
        
        conditions = [
            (hybrid_df['Macro_ER'] >= self.macro_er_threshold) & (hybrid_df.get('Theater_Risk_Pct', pd.Series([0]*len(hybrid_df))) < self.hmm_risk_threshold),
            (hybrid_df['Macro_ER'] >= self.macro_er_threshold) & (hybrid_df.get('Theater_Risk_Pct', pd.Series([0]*len(hybrid_df))) >= self.hmm_risk_threshold),
            (hybrid_df['Macro_ER'] < self.macro_er_threshold)
        ]
        
        choices = ['GREEN', 'YELLOW', 'RED']
        hybrid_df['Hybrid_Decision'] = np.select(conditions, choices, default='RED')
        
        return hybrid_df

    def evaluate_performance(self, hybrid_df):
        logger.info("\n📊 HIBRID DÖNTÉSI MÁTRIX TELJESÍTMÉNY ÉRTÉKELÉS 📊")
        
        # Csak a Trade nyitási pontokat vizsgáljuk, ha vannak megjelölve (PosCount változás alapján)
        if 'Target' not in hybrid_df.columns:
            logger.warning("Nincs Target oszlop az értékeléshez.")
            return
            
        total_trades = hybrid_df[(hybrid_df['Target'] == 0) | (hybrid_df['Target'] == 1)]
        target_1 = hybrid_df[hybrid_df['Target'] == 1] # Brókeri Manipuláció
        target_0 = hybrid_df[hybrid_df['Target'] == 0] # Tiszta Piac
        
        if len(total_trades) == 0:
            logger.info("A fájl nem tartalmaz trade eseményeket.")
            return
            
        report_text = f"\nÖsszes Vizsgált Trade (Esemény): {len(total_trades)}\n"
        report_text += "-" * 50 + "\n"
        
        # 1. Hány MANIPULÁCIÓT (Target=1) tudtunk volna ELKERÜLNI? (Mert a mátrix RED vagy YELLOW volt)
        saved_from_theater = len(target_1[target_1['Hybrid_Decision'].isin(['RED', 'YELLOW'])])
        t1_total = len(target_1)
        if t1_total > 0:
            report_text += f"Brókeri Trükkök (Target=1) elkerülve (Sikeres védelem): {saved_from_theater} / {t1_total} ({saved_from_theater/t1_total*100:.1f}%)\n"
        
        # 2. Hány JÓ TRADE-et (Target=0) RONTOTTUNK EL? (Mert a mátrix RED vagy YELLOW volt és tiltott)
        lost_good_trades = len(target_0[target_0['Hybrid_Decision'].isin(['RED', 'YELLOW'])])
        t0_total = len(target_0)
        if t0_total > 0:
            report_text += f"Jó Tradek (Target=0) elvesztve (Fals Riasztás): {lost_good_trades} / {t0_total} ({lost_good_trades/t0_total*100:.1f}%)\n"
            report_text += f"Sikeresen Engedélyezett Jó Tradek (ZÖLD): {t0_total - lost_good_trades} / {t0_total} ({(t0_total - lost_good_trades)/t0_total*100:.1f}%)\n"
            
        report_text += "-" * 50 + "\n"
        print(report_text)

def main():
    file_path = "reports_tmp/VAKU3_VALIDATED_LABELED_Merkava_EURUSD_v1.10_20260323_215749.csv"
    if not os.path.exists(file_path):
        # Fallback a data/labeled -re
        file_path = "data/labeled/VAKU3_VALIDATED_LABELED_Merkava_EURUSD_v1.10_20260323_215749.csv"
        
    logger.info(f"Fájl betöltése: {file_path}")
    
    # Megpróbáljuk betölteni
    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        logger.error(f"Hiba a fájl beolvasásakor: {e}")
        return
        
    engine = VakuHybridEngine(macro_timeframe_min=5, hmm_risk_threshold=20.0, macro_er_threshold=0.3)
    hybrid_df = engine.process_hybrid_matrix(df)
    
    if hybrid_df is not None:
        engine.evaluate_performance(hybrid_df)
        
        # Save output for visualization
        out_path = "reports_tmp/HYBRID_EVAL_EURUSD.csv"
        hybrid_df.to_csv(out_path, index=False)
        logger.info(f"Hibrid Dataframe kimentve: {out_path}")

if __name__ == "__main__":
    main()
