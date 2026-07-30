import pandas as pd
df = pd.read_csv('data/labeled_dollar_bars_3MTF_v3.csv')

def test_cols(script_path):
    with open(script_path, 'r') as f:
        content = f.read()
    import re
    match = re.search(r'ignore_cols\s*=\s*\[(.*?)\]', content, re.DOTALL)
    if match:
        lst_str = match.group(1).replace("'", "").replace('"', "").replace("\n", "").split(",")
        lst_str = [x.strip() for x in lst_str]
        features = [col for col in df.columns if col not in lst_str]
        print(f"{script_path}: {len(features)} features -> {features}")

test_cols('src/optuna_optimizer_3MTF_v3_regime.py')
test_cols('src/optuna_threshold_tuner_strict.py')
test_cols('src/trade_analyzer_v2.py')
test_cols('src/trade_analyzer_v3_deepdive.py')
test_cols('src/viz_regime_chart.py')
test_cols('src/optuna_architecture_tuner.py')
test_cols('src/train_arch.py')
