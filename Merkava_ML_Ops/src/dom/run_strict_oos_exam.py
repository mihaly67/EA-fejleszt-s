import os
import sys

def run_cmd(cmd):
    print(f"\n{'-'*60}")
    print(f"▶️ Futtatás: {cmd}")
    print(f"{'-'*60}")
    res = os.system(cmd)
    if res != 0:
        print(f"❌ Hiba történt a(z) {cmd} parancs közben!")
        sys.exit(1)

def run_pipeline(raw_csv_path):
    print("="*60)
    print("🚀 STRICT OUT-OF-SAMPLE (OOS) ÉLES VIZSGA PIPELINE")
    print("="*60)

    # Készítünk egy dedikált mappát a vizsga kimeneteinek
    out_dir = os.path.dirname(raw_csv_path)
    exam_dir = os.path.join(out_dir, 'exam_0720_23')
    os.makedirs(exam_dir, exist_ok=True)

    dollar_bars_csv = os.path.join(exam_dir, 'exam_dollar_bars.csv')
    features_csv = os.path.join(exam_dir, 'exam_features.csv')
    labeled_csv = os.path.join(exam_dir, 'exam_labeled.csv')

    # 1. Lépés: Dollar Bars Generálása
    # Alap küszöböt használunk: $444,000 forgalom
    run_cmd(f"/home/misi/ML_Ops/venv/bin/python3 /home/misi/Merkava_ML_Ops/src/dom/prado_dollar_bars.py {raw_csv_path}")

    # A prado_dollar_bars alapból a bemenet mappájába (data/processed/dollar_bars.csv) teszi
    # Mozgassuk át a mi dedikált exam mappánkba!
    default_out = os.path.join(out_dir, 'processed', 'dollar_bars.csv')
    if os.path.exists(default_out):
        os.rename(default_out, dollar_bars_csv)
    else:
        print("❌ Hiba: A Dollar Bar generálás nem hozott létre kimenetet.")
        sys.exit(1)

    # 2. Lépés: Feature Engineering (Bemelegítéssel és Shift(1) szivárgásmentesen)
    run_cmd(f"/home/misi/ML_Ops/venv/bin/python3 /home/misi/Merkava_ML_Ops/src/dom/dom_feature_engineer_mtf.py {dollar_bars_csv}")

    # Mivel a script default out-ja a forrás mappa
    default_feat_out = os.path.join(exam_dir, 'features_dollar_bars.csv')
    if os.path.exists(default_feat_out):
         os.rename(default_feat_out, features_csv)

    # 3. Lépés: Címkézés (Hogy legyen mihez viszonyítani a pontosságot)
    # BEKAPCSOLVA: Dinamikus ATR a vizsgában is!
    run_cmd(f"/home/misi/ML_Ops/venv/bin/python3 /home/misi/Merkava_ML_Ops/src/dom/dom_labeler_mtf.py {features_csv} --dynamic_atr")

    default_labeled_out = os.path.join(exam_dir, 'labeled_dollar_bars.csv')
    if os.path.exists(default_labeled_out):
         os.rename(default_labeled_out, labeled_csv)

    # 4. Lépés: Értékelés a teljesen szűz adaton
    run_cmd(f"/home/misi/ML_Ops/venv/bin/python3 /home/misi/Merkava_ML_Ops/src/dom/evaluate_strict_oos.py {labeled_csv}")

    print("\n✅ OOS VIZSGA PIPELINE BEFEJEZŐDÖTT!")

if __name__ == '__main__':
    raw_path = '/home/misi/Merkava_ML_Ops/data/Merkava_MTF_MGCQ26_0720_23_vizsga_Data.csv'
    if len(sys.argv) > 1:
        raw_path = sys.argv[1]
    run_pipeline(raw_path)
