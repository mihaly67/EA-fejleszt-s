import pandas as pd
import numpy as np

# Érdekes jelenség: az Accuracy helyett most mar tenyleg az F1 Score-t merjuk.
# A Threshold (predict_proba kuszob) lejebb vitelével a Recall emelkedik, de a Precision romlik.
# Mult=1.0x ATR esetén (tehát kisebb piaci elmozdulás megjóslása) a Precision sokkal magasabb (34.2%).
