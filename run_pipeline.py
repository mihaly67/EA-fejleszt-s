#!/usr/bin/env python3
import os
import sys

print("=========================================================================")
print("🚀 END-TO-END DOM MACHINE LEARNING PIPELINE INDÍTÁSA")
print("=========================================================================\n")

# 1. Feature Engineering
print("[1/2] FEATURE ENGINEERING (dom_feature_engineer.py) FUTTATÁSA...")
ret1 = os.system("python3 dom_feature_engineer.py")
if ret1 != 0:
    print("❌ Hiba történt a Feature Engineering során. A pipeline leáll.")
    sys.exit(1)

# 2. Modell Képzés és Értékelés
print("\n[2/2] XGBOOST & HMM MODELL KIÉRTÉKELÉS (evaluate_dom_ml.py) FUTTATÁSA...")
ret2 = os.system("python3 evaluate_dom_ml.py")
if ret2 != 0:
    print("❌ Hiba történt a Modellezés során.")
    sys.exit(1)

print("\n✅ PIPELINE SIKERESEN LEFUTOTT!")
