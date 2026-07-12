import os
import sys

print("="*40)
print("DOM HUD - END-TO-END VAKU 3 PIPELINE")
print("="*40)

def run(cmd):
    print(f"\n>>> Futtatás: {cmd}")
    res = os.system(cmd)
    if res != 0:
        print(f"Hiba a következő parancsban: {cmd}")
        sys.exit(1)

cat_script = """
import sys
from dom_feature_engineer import DOMFeatureEngineer
print("OOS FEATURE ENGINEERING...")
eng_oos = DOMFeatureEngineer('data/DOM_Data_20260710_050837.csv', 'data/processed/engineered_oos.csv')
eng_oos.process()
"""
with open("prep_all.py", "w") as f:
    f.write(cat_script)

run("python3 dom_train_pipeline.py")
run("python3 prep_all.py")
run("python3 dom_inference_exam.py")

print("\nPipeline Kész.")
