#!/bin/bash
export SSHPASS='1104'
sshpass -e scp -o StrictHostKeyChecking=no misi@5.189.163.88:/home/misi/Merkava_ML_Ops/src/feature_importance.png ./feature_importance.png
