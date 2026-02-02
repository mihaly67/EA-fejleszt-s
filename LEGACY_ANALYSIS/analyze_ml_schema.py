import json
import re

FILE_PATH = "Knowledge_Base/knowledge_base_thiefs_library.jsonl"
OUTPUT_REPORT = "ML_DATA_REQUIREMENTS.md"

def analyze_finrl(data):
    """Extracts state space and indicator lists from FinRL code."""
    filename = data.get("filename", "")
    code = data.get("code", "")

    findings = []

    # 1. Look for INDICATORS_LIST in config or constants
    if "config" in filename or "constants" in filename:
        matches = re.findall(r'[A-Z_]*INDICATORS_LIST\s*=\s*\[(.*?)\]', code, re.DOTALL)
        if matches:
            findings.append(f"**Indicators List ({filename}):**\n```python\n{matches[0].strip()}\n```")

    # 2. Look for State Space definition in Environments
    if "env" in filename.lower() and "class" in code:
        # Simple heuristic to find state definition or observation space
        if "self.state" in code or "observation_space" in code:
            # Try to grab the _initiate_state or reset method
            method_match = re.search(r'def _initiate_state\(self\).*?:(.*?)return', code, re.DOTALL)
            if method_match:
                findings.append(f"**State Initialization ({filename}):**\n```python\n{method_match.group(1).strip()[:500]}...\n```")

            # Look for feature engineering / covariance
            if "covariance" in code:
                findings.append(f"**Covariance Matrix Usage ({filename}):** Found references to covariance type features.")

    return findings

def analyze_nautilus(data):
    """Checks Nautilus for data bar structures."""
    filename = data.get("filename", "")
    code = data.get("code", "")
    findings = []

    if "bar.py" in filename or "quote.py" in filename:
         if "class Bar" in code or "class Quote" in code:
             # Just list the fields if possible (simple regex for slots or init)
             slots = re.search(r'__slots__\s*=\s*\((.*?)\)', code, re.DOTALL)
             if slots:
                 findings.append(f"**Nautilus Data Structure ({filename}):**\n```python\n{slots.group(1).strip()}\n```")
    return findings

def main():
    print("🧠 Analyzing Thief's Library for ML Schemas...")

    finrl_findings = []
    nautilus_findings = []

    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                data = json.loads(line)
                source = data.get("source", "")

                if "FinRL" in source:
                    res = analyze_finrl(data)
                    if res: finrl_findings.extend(res)

                if "nautilus" in source:
                    res = analyze_nautilus(data)
                    if res: nautilus_findings.extend(res)

            except: pass

    # Write Report
    with open(OUTPUT_REPORT, 'w') as f:
        f.write("# ML Data Requirements Report\n\n")

        f.write("## 1. FinRL (Reinforcement Learning Standard)\n")
        f.write("FinRL typically expects a standardized state space containing technical indicators.\n\n")
        if finrl_findings:
            for item in finrl_findings:
                f.write(item + "\n\n")
        else:
            f.write("No specific schema definitions found in FinRL files.\n")

        f.write("## 2. Nautilus Trader (Event Engine)\n")
        f.write("Nautilus uses strict data structures for high-performance backtesting.\n\n")
        if nautilus_findings:
            for item in nautilus_findings:
                f.write(item + "\n\n")
        else:
            f.write("No specific slots/structure found for Nautilus.\n")

    print(f"✅ Report generated: {OUTPUT_REPORT}")

if __name__ == "__main__":
    main()
