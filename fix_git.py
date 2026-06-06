import subprocess
import os

env = os.environ.copy()
env['GIT_TERMINAL_PROMPT'] = '0'

print("1. ABORT REBASE")
subprocess.run(["git", "rebase", "--abort"], env=env)

print("2. FETCH")
subprocess.run(["git", "fetch", "origin", "main"], env=env)

print("3. RESET TO ORIGIN/MAIN")
subprocess.run(["git", "reset", "--mixed", "origin/main"], env=env)

print("4. ADD ALL")
subprocess.run(["git", "add", "-A"], env=env)

print("5. COMMIT")
subprocess.run(["git", "commit", "-m", "feat: Add Dashboard V6, Hybrid Engine, and Sync VPS scripts"], env=env)

print("6. PUSH")
push_res = subprocess.run(
    ["git", "push", "origin", "HEAD:main"],
    env=env,
    capture_output=True,
    text=True
)
print(push_res.stdout)
print(push_res.stderr)
