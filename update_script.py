with open('vaku3_offline_validator_VPS.py', 'r') as f:
    c = f.read()

c = c.replace('state_hits = {0: 0, 1: 0, 2: 0}', 'state_hits = {0: 0, 1: 0, 2: 0, np.nan: 0}')
with open('vaku3_offline_validator_VPS.py', 'w') as f:
    f.write(c)

