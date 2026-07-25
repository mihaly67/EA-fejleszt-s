#!/bin/bash
set -e
export VENV_PY="/home/misi/ML_Ops/venv/bin/python3"

echo "=========================================="
echo "🚀 1. DOLLAR BAR GENERÁLÁS (Tanító Halmaz)"
echo "=========================================="
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/prado_dollar_bars.py /home/misi/Merkava_ML_Ops/data/Merkava_MTF_MGCQ26_20260527_0717_Data.csv

echo "=========================================="
echo "🚀 2. FEATURE ENGINEERING (Tanító Halmaz)"
echo "=========================================="
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/dom_feature_engineer_mtf.py /home/misi/Merkava_ML_Ops/data/processed/dollar_bars.csv

echo "=========================================="
echo "🚀 3. CÍMKÉZÉS (Tanító Halmaz)"
echo "=========================================="
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/dom_labeler_mtf.py /home/misi/Merkava_ML_Ops/data/processed/features_dollar_bars.csv --dynamic_atr

echo "=========================================="
echo "🚀 4. MODELL TANÍTÁS (LightGBM) & VIZUALIZÁCIÓ"
echo "=========================================="
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/dom_model_trainer_mtf.py
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/visualize_decisions.py /home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv
mv /home/misi/Merkava_ML_Ops/data/processed/decision_visualization.html /home/misi/Merkava_ML_Ops/data/decision_visualization_train.html

echo "=========================================="
echo "🚀 5. DOLLAR BAR GENERÁLÁS (Vizsga Halmaz)"
echo "=========================================="
mkdir -p /home/misi/Merkava_ML_Ops/data/exam_new/
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/prado_dollar_bars.py /home/misi/Merkava_ML_Ops/data/Merkava_MTF_MGCQ26_vizsga_0720_0724_Data.csv
mv /home/misi/Merkava_ML_Ops/data/processed/dollar_bars.csv /home/misi/Merkava_ML_Ops/data/exam_new/exam_dollar_bars.csv

echo "=========================================="
echo "🚀 6. FEATURE ENGINEERING (Vizsga Halmaz)"
echo "=========================================="
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/dom_feature_engineer_mtf.py /home/misi/Merkava_ML_Ops/data/exam_new/exam_dollar_bars.csv
mv /home/misi/Merkava_ML_Ops/data/processed/features_dollar_bars.csv /home/misi/Merkava_ML_Ops/data/exam_new/exam_features.csv

echo "=========================================="
echo "🚀 7. CÍMKÉZÉS (Vizsga Halmaz)"
echo "=========================================="
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/dom_labeler_mtf.py /home/misi/Merkava_ML_Ops/data/exam_new/exam_features.csv --dynamic_atr
mv /home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv /home/misi/Merkava_ML_Ops/data/exam_new/exam_labeled.csv

echo "=========================================="
echo "🚀 8. STRICT OOS ÉRTÉKELÉS (Vizsga Halmaz)"
echo "=========================================="
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/evaluate_strict_oos.py /home/misi/Merkava_ML_Ops/data/exam_new/exam_labeled.csv

echo "=========================================="
echo "🚀 9. VIZUALIZÁCIÓ (Vizsga Halmaz)"
echo "=========================================="
$VENV_PY /home/misi/Merkava_ML_Ops/src/dom/visualize_decisions.py /home/misi/Merkava_ML_Ops/data/exam_new/exam_labeled.csv
mv /home/misi/Merkava_ML_Ops/data/exam_new/decision_visualization.html /home/misi/Merkava_ML_Ops/data/decision_visualization_exam.html

echo "✅ TELJES PIPELINE KÉSZ!"
