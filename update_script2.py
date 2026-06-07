with open('vaku3_offline_validator_VPS.py', 'r') as f:
    c = f.read()

c = c.replace('state_name = state_names[state_id]', 'state_name = state_names.get(state_id, "Unknown")')

with open('vaku3_offline_validator_VPS.py', 'w') as f:
    f.write(c)

