import os
import subprocess
import shutil

# Configuration
REPOS = {
    "hummingbot": "https://github.com/hummingbot/hummingbot.git",
    "FinRL": "https://github.com/AI4Finance-Foundation/FinRL.git",
    "vectorbt": "https://github.com/polakowo/vectorbt.git",
    "nautilus_trader": "https://github.com/nautechsystems/nautilus_trader.git",
    "context7": "https://github.com/upstash/context7.git"
}

BASE_DIR = "downloaded_content"

def run_command(cmd, cwd=None):
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running '{cmd}': {e.stderr}")
        return None

def fetch_repos():
    if not os.path.exists(BASE_DIR):
        os.makedirs(BASE_DIR)

    for name, url in REPOS.items():
        repo_path = os.path.join(BASE_DIR, name)

        print(f"\n🔹 Processing {name}...")

        if os.path.exists(repo_path):
            print(f"   Deleting existing directory {repo_path} to ensure clean slate...")
            shutil.rmtree(repo_path)

        # Clone
        print(f"   Cloning from {url}...")
        run_command(f"git clone {url} {name}", cwd=BASE_DIR)

        if not os.path.exists(repo_path):
            print(f"❌ Failed to clone {name}")
            continue

        # Fetch all branches
        print("   Fetching all branches...")
        run_command("git fetch --all", cwd=repo_path)

        # Identify 'development' branch
        # Logic: Look for 'develop', 'dev', 'next', 'unstable' in remote branches
        remotes = run_command("git branch -r", cwd=repo_path)
        if remotes:
            branches = [b.strip().replace("origin/", "") for b in remotes.split('\n')]

            target_branch = None
            priorities = ['develop', 'dev', 'development', 'next', 'unstable', 'main', 'master']

            for p in priorities:
                if p in branches:
                    target_branch = p
                    break

            if target_branch:
                print(f"   👉 Checking out target branch: '{target_branch}'")
                run_command(f"git checkout {target_branch}", cwd=repo_path)
                run_command(f"git pull origin {target_branch}", cwd=repo_path)
            else:
                print("   ⚠️ No specific development branch found. Staying on default.")

        # Show status
        current = run_command("git branch --show-current", cwd=repo_path)
        commit = run_command("git rev-parse --short HEAD", cwd=repo_path)
        print(f"   ✅ Active: {current} ({commit})")

if __name__ == "__main__":
    fetch_repos()
