#!/bin/bash

# Base directories
BASE="/home/misi/LGBM_mlops"
MICRO="$BASE/Micro_LGBM/src"
MACRO="$BASE/Macro_Regime/src"
LIVE="$BASE/Live_Trading/src"
SHARED="$BASE/Shared_Utils"

# Create directories if they don't exist
mkdir -p "$MICRO"
mkdir -p "$MACRO"
mkdir -p "$LIVE"
mkdir -p "$SHARED"

# --- 1. Shared Utilities (Used by both Macro and Micro) ---
mv "$BASE/kaufman_ama.py" "$SHARED/" 2>/dev/null
mv "$BASE/Macro_Regime/kaufman_ama.py" "$SHARED/" 2>/dev/null
mv "$BASE/pipeline_master.py" "$BASE/" 2>/dev/null  # Keep pipeline master in root

# --- 2. Micro LGBM (Momentum / Dollar Bars) ---
mv "$BASE/prado_dollar_bars.py" "$MICRO/" 2>/dev/null
mv "$BASE/fuse_macro_to_dollar_bars.py" "$MICRO/" 2>/dev/null
mv "$BASE/dom_labeler_v4.py" "$MICRO/" 2>/dev/null
mv "$BASE/dom_labeler_v5.py" "$MICRO/" 2>/dev/null
mv "$BASE/train_lgbm_fusion_v5.py" "$MICRO/" 2>/dev/null
mv "$BASE/optuna_lgbm_fusion_tuner.py" "$MICRO/" 2>/dev/null

# --- 3. Macro Regime (Time-based structural modeling) ---
mv "$BASE/Macro_Regime/macro_feature_engineer.py" "$MACRO/" 2>/dev/null
mv "$BASE/Macro_Regime/macro_labeler.py" "$MACRO/" 2>/dev/null
mv "$BASE/Macro_Regime/train_catboost_classifier.py" "$MACRO/" 2>/dev/null
mv "$BASE/Macro_Regime/train_ridge_classifier.py" "$MACRO/" 2>/dev/null
mv "$BASE/Macro_Regime/optuna_catboost_tuner.py" "$MACRO/" 2>/dev/null
mv "$BASE/Macro_Regime/evaluate_catboost_exam.py" "$MACRO/" 2>/dev/null
mv "$BASE/Macro_Regime/trade_analyzer_meta_regime.py" "$MACRO/" 2>/dev/null

# --- 4. Live Trading & HUD ---
mv "$BASE/mt5_live_copilot.py" "$LIVE/" 2>/dev/null
mv "$BASE/copilot_hud.py" "$LIVE/" 2>/dev/null
mv "$BASE/start_hud.sh" "$LIVE/" 2>/dev/null

echo "Organization complete. Checking structures:"
ls -la "$MICRO"
ls -la "$MACRO"
ls -la "$LIVE"
ls -la "$SHARED"
