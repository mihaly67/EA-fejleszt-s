import json
import os
import sys

# Konfiguráció
JSONL_PATH = "Knowledge_Base/MI6/MI6.jsonl"
OUTPUT_PATH = "Knowledge_Base/MI6/mi6_findings.json"
BATCH_SIZE = 500  # Ennyi sort olvasunk be egyszerre a memóriába

# Kulcsszavak, amikre vadászunk (Browser Fingerprinting & Telemetry)
TARGET_KEYWORDS = [
    "fingerprintjs",
    "amiunique",
    "canvas",
    "webgl",
    "webrtc",
    "telemetry",
    "crash-reports",
    "analytics",
    "tracking",
    "user-agent",
    "screen.width",
    "screen.height",
    "navigator.plugins",
    "navigator.language",
    "timezone",
    "font"
]

def analyze_mi6():
    print("🕵️ MI6 Elemzés Indítása (Batch Mode)...")

    if not os.path.exists(JSONL_PATH):
        print(f"❌ Hiba: Nem található a fájl: {JSONL_PATH}")
        return

    findings = []
    line_count = 0
    match_count = 0

    try:
        with open(JSONL_PATH, 'r', encoding='utf-8') as f:
            batch = []
            for line in f:
                line_count += 1
                batch.append(line)

                # Ha elértük a batch méretet, feldolgozzuk
                if len(batch) >= BATCH_SIZE:
                    matches = process_batch(batch)
                    findings.extend(matches)
                    match_count += len(matches)
                    print(f"   Processed {line_count} lines... Found {match_count} matches so far.")
                    batch = []  # Memória ürítése

            # Maradék feldolgozása
            if batch:
                matches = process_batch(batch)
                findings.extend(matches)
                match_count += len(matches)

    except Exception as e:
        print(f"❌ Hiba történt olvasás közben: {e}")

    # Eredmények mentése
    print(f"\n✅ Elemzés kész. Összesen {match_count} találat {line_count} sorból.")
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as out:
        json.dump(findings, out, indent=2)
    print(f"📄 Jelentés mentve: {OUTPUT_PATH}")

def process_batch(lines):
    """Egy batch feldolgozása és a kulcsszavak keresése."""
    batch_matches = []
    for line_str in lines:
        try:
            entry = json.loads(line_str)
            code = entry.get("code", "").lower()
            filename = entry.get("filename", "")

            # Keresés
            found_keywords = [kw for kw in TARGET_KEYWORDS if kw in code or kw in filename.lower()]

            if found_keywords:
                # Csak a releváns adatokat mentjük el, hogy spóroljunk a hellyel
                batch_matches.append({
                    "file": filename,
                    "keywords": found_keywords,
                    "snippet": code[:200] + "..." if len(code) > 200 else code # Csak az elejét mentjük
                })
        except json.JSONDecodeError:
            continue
    return batch_matches

if __name__ == "__main__":
    analyze_mi6()
