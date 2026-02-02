import os
import json
from datetime import datetime

# --- CONFIGURATION ---
PARENT_DIR = "." # Run this inside 'Github colombo repo'
REPO_DIRS = [
    "alibi-detect-master",
    "causalml-master",
    "chaosmonkey-master",
    "dowhy-main",
    "mlfinlab-master",
    "open_spiel-master",
    "perspective-master",
    "PettingZoo-master",
    "pyod-master",
    "quantstats-main",
    "swift-composable-architecture-main"
]

# Extensions to Audit (Broad Range)
KNOWLEDGE_EXTENSIONS = {
    # Code
    '.py', '.ipynb', '.js', '.ts', '.cpp', '.hpp', '.h', '.c', '.go', '.rs', '.java', '.jl', '.r', '.m', '.swift',
    # Docs
    '.md', '.rst', '.txt',
    # Config/Data
    '.json', '.yaml', '.yml', '.toml', '.xml', '.csv'
}

OUTPUT_REPORT = "COLUMBO_REPO_AUDIT.txt"

def scan_repos():
    print(f"🕵️ COLUMBO SCANNER: Starting Audit in '{os.path.abspath(PARENT_DIR)}'...")

    report_lines = []
    report_lines.append(f"COLUMBO REPO AUDIT REPORT")
    report_lines.append(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report_lines.append("==================================================")

    total_files_found = 0
    total_size_mb = 0

    for repo_name in REPO_DIRS:
        repo_path = os.path.join(PARENT_DIR, repo_name)

        report_lines.append(f"\n📂 REPO: {repo_name}")
        print(f"   Scanning {repo_name}...")

        if not os.path.exists(repo_path):
            msg = f"   ❌ NOT FOUND: {repo_path}"
            print(msg)
            report_lines.append(msg)
            continue

        # Stats per repo
        repo_file_count = 0
        repo_size_bytes = 0
        ext_counts = {}

        for root, dirs, files in os.walk(repo_path):
            # Skip hidden dirs
            dirs[:] = [d for d in dirs if not d.startswith('.')]

            for file in files:
                ext = os.path.splitext(file)[1].lower()

                # Check if it's a file we care about (or log all?)
                # Let's log stats for ALL, but highlight knowledge ones
                if ext not in ext_counts: ext_counts[ext] = 0
                ext_counts[ext] += 1

                file_path = os.path.join(root, file)
                try:
                    size = os.path.getsize(file_path)
                    repo_size_bytes += size
                    repo_file_count += 1
                except:
                    pass

        repo_size_mb = repo_size_bytes / (1024 * 1024)
        total_files_found += repo_file_count
        total_size_mb += repo_size_mb

        report_lines.append(f"   - Files: {repo_file_count}")
        report_lines.append(f"   - Size: {repo_size_mb:.2f} MB")
        report_lines.append(f"   - Extensions:")

        # Sort extensions by count
        sorted_exts = sorted(ext_counts.items(), key=lambda x: x[1], reverse=True)
        for ext, count in sorted_exts:
            mark = "✅" if ext in KNOWLEDGE_EXTENSIONS else "  "
            report_lines.append(f"     {mark} {ext}: {count}")

    report_lines.append("\n==================================================")
    report_lines.append(f"GRAND TOTAL:")
    report_lines.append(f"   - Files Scanned: {total_files_found}")
    report_lines.append(f"   - Total Size: {total_size_mb:.2f} MB")

    # Write Report
    with open(OUTPUT_REPORT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(report_lines))

    print(f"\n✅ Audit Complete. Report saved to: {OUTPUT_REPORT}")
    print(f"   Total Found: {total_files_found} files ({total_size_mb:.2f} MB)")

if __name__ == "__main__":
    scan_repos()
