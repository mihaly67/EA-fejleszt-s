import subprocess
import os

env = os.environ.copy()
env['GIT_TERMINAL_PROMPT'] = '0'

print("4. ADD ALL")
subprocess.run(["git", "add", "-A"], env=env)

print("5. COMMIT (amend)")
subprocess.run(["git", "commit", "--amend", "-m", "feat: Add Dashboard V6, Hybrid Engine, and Sync VPS scripts"], env=env)

print("6. PUSH")
push_res = subprocess.run(
    ["git", "push", "origin", "HEAD:main", "--force"],
    env=env,
    capture_output=True,
    text=True
)
print(push_res.stdout)
print(push_res.stderr)
