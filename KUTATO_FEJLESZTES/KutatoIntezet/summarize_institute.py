import json
import os
import sys

def summarize(json_files):
    report = "# A KUTATÓINTÉZET TANULMÁNYA\n\n"
    total_docs = 0
    total_jobs = 0

    for level, filename in enumerate(json_files):
        if not os.path.exists(filename): continue

        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
            results = data.get('results', [])
            next_jobs = data.get('next_jobs', [])

            report += f"## Szint {level} (Eredmények)\n"
            report += f"- Feldolgozott Feladatok (Input Jobs): {len(data.get('input_jobs', []))}\n"
            report += f"- Generált Találatok (Results): {len(results)}\n"
            report += f"- Új Kutatási Irányok (Next Jobs): {len(next_jobs)}\n\n"

            report += "### Kiemelt Találatok:\n"
            for i, res in enumerate(results[:3]): # Top 3 per level
                report += f"**{i+1}. [{res.get('source_type', '?')}] {res.get('filename', '?')}**\n"
                report += f"> {res.get('content', '')[:200]}...\n\n"

            report += "### Generált Kulcsszavak (Minta):\n"
            keywords = [job['query'] for job in next_jobs[:5]]
            report += f"{', '.join(keywords)}\n\n"
            report += "---\n\n"

            total_docs += len(results)
            total_jobs += len(next_jobs)

    report += f"# ÖSSZEGZÉS\n"
    report += f"A kutatás során összesen **{total_docs}** dokumentumot dolgoztunk fel és **{total_jobs}** új kutatási irányt azonosítottunk.\n"

    print(report)
    with open("KUTATO_FEJLESZTES/KutatoIntezet/TANULMANY.md", "w", encoding="utf-8") as f:
        f.write(report)

if __name__ == "__main__":
    files = [
        "KUTATO_FEJLESZTES/KutatoIntezet/level_0.json",
        "KUTATO_FEJLESZTES/KutatoIntezet/level_1.json",
        "KUTATO_FEJLESZTES/KutatoIntezet/level_2.json"
    ]
    summarize(files)
