#!/bin/bash
cd /home/misi/LGBM_mlops
source venv_3MTF/bin/activate
python3 src/optuna_optimizer_3MTF_v3_regime.py > optuna_regime.log 2>&1 &
