import subprocess
import os

env = os.environ.copy()
env['GIT_TERMINAL_PROMPT'] = '0'

print("PULLING...")
pull_res = subprocess.run(
    ["git", "pull", "origin", "main", "--rebase"],
    env=env,
    capture_output=True,
    text=True
)
print("PULL STDOUT:", pull_res.stdout)
print("PULL STDERR:", pull_res.stderr)

print("PUSHING...")
push_res = subprocess.run(
    ["git", "push", "origin", "HEAD:main"],
    env=env,
    capture_output=True,
    text=True
)
print("PUSH STDOUT:", push_res.stdout)
print("PUSH STDERR:", push_res.stderr)
