#!/bin/bash
cd /home/misi/Merkava_ML_Ops/src/dom/
sed -i 's/print("🔨 Filtering Trading Hours (08:00 - 23:59)")/print("🔨 Trading Hours: 00:00 - 24:00 (Nonstop)")/g' dom_feature_engineer_mtf1-60.py
sed -i "s/df = df\[df\['Hour'\] >= 8\].copy()/# Nonstop mode - no filtering\n        # df = df[df['Hour'] >= 8].copy()/g" dom_feature_engineer_mtf1-60.py
