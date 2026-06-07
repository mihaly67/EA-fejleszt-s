import re

with open("vaku3_online_hybrid.py", "r") as f:
    content = f.read()

content = content.replace("from utils.ring_buffer import O1RingBuffer", "from ANALYSIS_TOOLS.ML_Ops.utils.ring_buffer import O1RingBuffer")
content = content.replace("from utils.log_er_scaler import LogERScaler", "from ANALYSIS_TOOLS.ML_Ops.utils.log_er_scaler import LogERScaler")
with open("vaku3_online_hybrid.py", "w") as f:
    f.write(content)
