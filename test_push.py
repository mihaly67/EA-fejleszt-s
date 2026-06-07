import subprocess
import os

env = os.environ.copy()
env['GIT_TERMINAL_PROMPT'] = '0'

result = subprocess.run(
    ["git", "push", "origin", "jules-dashboard-v3-predictive"],
    env=env,
    capture_output=True,
    text=True
)
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
