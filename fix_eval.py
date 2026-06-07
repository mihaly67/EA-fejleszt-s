import re

with open("vaku3_hybrid_engine_fixed.py", "r", encoding="utf-8") as f:
    content = f.read()

eval_old = """    def evaluate_performance(self, hybrid_df):
        logger.info("\\n📊 HIBRID DÖNTÉSI MÁTRIX TELJESÍTMÉNY ÉRTÉKELÉS 📊")

        # Csak a Trade nyitási pontokat vizsgáljuk, ha vannak megjelölve (PosCount változás alapján)
        if 'Target' not in hybrid_df.columns:
            logger.warning("Nincs Target oszlop az értékeléshez.")
            return

        total_trades = hybrid_df[(hybrid_df['Target'] == 0) | (hybrid_df['Target'] == 1)]"""

eval_new = """    def evaluate_performance(self, hybrid_df):
        logger.info("\\n📊 HIBRID DÖNTÉSI MÁTRIX TELJESÍTMÉNY ÉRTÉKELÉS 📊")

        # Csak a Trade nyitási pontokat vizsgáljuk, ha vannak megjelölve (PosCount változás alapján)
        if 'Target' not in hybrid_df.columns:
            logger.warning("Nincs Target oszlop az értékeléshez.")
            return

        with open('reports_tmp/HYBRID_EVAL_REPORT.txt', 'w', encoding='utf-8') as f:
            f.write("📊 HIBRID DÖNTÉSI MÁTRIX TELJESÍTMÉNY ÉRTÉKELÉS 📊\\n")
            total_trades = hybrid_df[(hybrid_df['Target'] == 0) | (hybrid_df['Target'] == 1)]"""

content = content.replace(eval_old, eval_new)

print_old = """        if len(total_trades) == 0:
            logger.info("A fájl nem tartalmaz trade eseményeket.")
            return

        print(f"\\nÖsszes Vizsgált Trade (Esemény): {len(total_trades)}")
        print("-" * 50)

        # 1. Hány MANIPULÁCIÓT (Target=1) tudtunk volna ELKERÜLNI? (Mert a mátrix RED vagy YELLOW volt)
        saved_from_theater = len(target_1[target_1['Hybrid_Decision'].isin(['RED', 'YELLOW'])])
        t1_total = len(target_1)
        if t1_total > 0:
            print(f"Brókeri Trükkök (Target=1) elkerülve (Sikeres védelem): {saved_from_theater} / {t1_total} ({saved_from_theater/t1_total*100:.1f}%)")

        # 2. Hány JÓ TRADE-et (Target=0) RONTOTTUNK EL? (Mert a mátrix RED vagy YELLOW volt és tiltott)
        lost_good_trades = len(target_0[target_0['Hybrid_Decision'].isin(['RED', 'YELLOW'])])
        t0_total = len(target_0)
        if t0_total > 0:
            print(f"Jó Tradek (Target=0) elvesztve (Fals Riasztás): {lost_good_trades} / {t0_total} ({lost_good_trades/t0_total*100:.1f}%)")
            print(f"Sikeresen Engedélyezett Jó Tradek (ZÖLD): {t0_total - lost_good_trades} / {t0_total} ({(t0_total - lost_good_trades)/t0_total*100:.1f}%)")

        print("-" * 50)"""

print_new = """        if len(total_trades) == 0:
            logger.info("A fájl nem tartalmaz trade eseményeket.")
            return

        with open('reports_tmp/HYBRID_EVAL_REPORT.txt', 'a', encoding='utf-8') as f:
            f.write(f"\\nÖsszes Vizsgált Trade (Esemény): {len(total_trades)}\\n")
            f.write("-" * 50 + "\\n")

            # 1. Hány MANIPULÁCIÓT (Target=1) tudtunk volna ELKERÜLNI? (Mert a mátrix RED vagy YELLOW volt)
            saved_from_theater = len(target_1[target_1['Hybrid_Decision'].isin(['RED', 'YELLOW'])])
            t1_total = len(target_1)
            if t1_total > 0:
                f.write(f"Brókeri Trükkök (Target=1) elkerülve (Sikeres védelem): {saved_from_theater} / {t1_total} ({saved_from_theater/t1_total*100:.1f}%)\\n")

            # 2. Hány JÓ TRADE-et (Target=0) RONTOTTUNK EL? (Mert a mátrix RED vagy YELLOW volt és tiltott)
            lost_good_trades = len(target_0[target_0['Hybrid_Decision'].isin(['RED', 'YELLOW'])])
            t0_total = len(target_0)
            if t0_total > 0:
                f.write(f"Jó Tradek (Target=0) elvesztve (Fals Riasztás): {lost_good_trades} / {t0_total} ({lost_good_trades/t0_total*100:.1f}%)\\n")
                f.write(f"Sikeresen Engedélyezett Jó Tradek (ZÖLD): {t0_total - lost_good_trades} / {t0_total} ({(t0_total - lost_good_trades)/t0_total*100:.1f}%)\\n")

            f.write("-" * 50 + "\\n")"""

content = content.replace(print_old, print_new)

with open("vaku3_hybrid_engine_eval.py", "w", encoding="utf-8") as f:
    f.write(content)
