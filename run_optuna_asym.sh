#!/bin/bash
cd /home/misi/LGBM_mlops
source venv_3MTF/bin/activate
python3 src/optuna_optimizer_3MTF_v2_asymmetric.py > optuna_asym.log 2>&1 &
