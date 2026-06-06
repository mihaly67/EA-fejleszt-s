import re

with open("vaku3_offline_validator_VPS_new.py", "r", encoding="utf-8") as f:
    content = f.read()

# Change covariance_type to full
content = content.replace('covariance_type="diag"', 'covariance_type="full"')

with open("vaku3_offline_validator_VPS_full.py", "w", encoding="utf-8") as f:
    f.write(content)
