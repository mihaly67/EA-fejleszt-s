import sys

with open("/home/misi/Merkava_ML_Ops/evaluate_dom_ml.py", "r") as f:
    content = f.read()

# Fix the SHAP output logic for multi-class XGBoost handling
search_block = """            if isinstance(shap_values, list):
                mean_shap = np.mean([np.abs(sv).mean(axis=0) for sv in shap_values], axis=0)
            else:
                mean_shap = np.abs(shap_values).mean(axis=0)"""

replace_block = """            # In newer shap versions for multi-class, shap_values is a 3D array: (samples, features, classes)
            if len(np.shape(shap_values)) == 3:
                mean_shap = np.mean(np.abs(shap_values), axis=(0, 2))
            elif isinstance(shap_values, list):
                mean_shap = np.mean([np.abs(sv).mean(axis=0) for sv in shap_values], axis=0)
            else:
                mean_shap = np.abs(shap_values).mean(axis=0)"""

content = content.replace(search_block, replace_block)

# Let's adjust confidence to 65% since 50% was producing too many bad trades (1.3% win rate)
content = content.replace('0.50)', '0.65)')

with open("/home/misi/Merkava_ML_Ops/evaluate_dom_ml.py", "w") as f:
    f.write(content)
