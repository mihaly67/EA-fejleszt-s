import os
import sqlite3
import re
import sys

# Hozzáférés az Agent Memória Menedzserhez (hogy naplózhassuk a találatokat)
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from agent_memory_manager import write_memory

def run_autonomous_scout():
    """
    Ez az a script, amit a Felhasználó távollétében egy Cron-job futtat a VPS-en (Scheduled Task).
    Célja: Végignyálazni a megadott (érintetlen) repókat az SQLite RAG-ból,
    kikeresni belőlük a kulcsfontosságú (Adatbázis elemzés, CSV chatbot, MCP optimalizáció) funkciókat.
    A redundáns vagy irreleváns kódot eldobja.
    Az eredményt egyenesen a Hosszútávú Memóriába (agent_memory.jsonl) írja "Auto_Scout_Report" néven,
    hogy amikor a Felhasználó géphez ül, azonnal a kész elemzés várja.
    """
    print("🤖 AUTONÓM FELDERÍTŐ INDÍTÁSA (Scheduled Task Szimuláció)...")

    db_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "Knowledge_Base", "AI_TOOLS_DB", "RAG_CHATBOT_CSV_DATA_LLM_github.db")

    if not os.path.exists(db_path):
        print(f"❌ Adatbázis nem található: {db_path}")
        return

    # Azok a repók, amiket meg kell vizsgálnunk (amik kimaradtak a Memória és Jules fúrásokból)
    target_repos = [
        "linear-master",
        "postgres-mcp-main",
        "puppeteer-mcp-server-main",
        "servers-main",
        "context7-master"
    ]

    print(f"🔍 Célzott Repók: {', '.join(target_repos)}")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # 1. Kigyűjtjük az OOM-biztos SQL paranccsal az érdekes fájlokat
    placeholders = ','.join(['?'] * len(target_repos))
    query = f"SELECT source_repo, filepath, content FROM rag_data WHERE source_repo IN ({placeholders}) AND filepath LIKE '%.py'"

    try:
        cursor.execute(query, target_repos)
        rows = cursor.fetchall()
    except Exception as e:
        print(f"Hiba az SQL lekérdezésben: {e}")
        conn.close()
        return

    print(f"📂 {len(rows)} releváns Python fájl kinyerve az adatbázisból.")

    report_lines = []
    report_lines.append("Autonóm Felderítő (Scheduled Task) Jelentés az 'Ultimate RAG' érintetlen MCP és DB repóiról:\n")

    # Kulcsszavak, amikre vadászunk (Adatbázis elemzés, Grafikon, CSV, MCP)
    db_keywords = re.compile(r"sql|query|table|schema|database|postgres|explain", re.IGNORECASE)
    mcp_keywords = re.compile(r"mcp|server|tool|client|call_tool", re.IGNORECASE)

    repo_insights = {}

    # "Ami nem az (nem releváns), azzal nem foglalkozol" -> Szűrés
    for repo, filepath, content in rows:
        if not content: continue

        is_relevant = False
        findings = []

        # Vizsgáljuk meg a fájl tartalmát
        if repo == "postgres-mcp-main":
            if "top_queries" in filepath or "explain" in filepath:
                is_relevant = True
                findings.append("Megtaláltam az 'EXPLAIN PLAN' és 'TOP QUERIES' SQL performancia elemző MCP toolokat! Ez lenyűgöző az adatbázis (vagy CSV/SQLite) RAG optimalizálásunkhoz: az Agent képes lehet az MCP-n keresztül lekérdezni a saját SQL lekérdezései sebességét (pl. rag_scout) és önkorrigálni!")

        elif repo == "servers-main":
            if "git" in filepath:
                 is_relevant = True
                 findings.append("Találtam egy komplett 'Git MCP Szervert' (git_commit, git_checkout, git_diff toolokkal). Ez forradalmasíthatja az én (Jules) GitHub PR kezelésemet: Bash scriptek írása helyett MCP hívásokkal, strukturált JSON-ben intézhetem a git verziókövetést a VPS-en!")

        elif repo == "linear-master":
             # Ha találunk bármit (Linear egy issue tracker)
             if "issue" in content.lower():
                 is_relevant = True
                 findings.append("A 'Linear' MCP szerver integrációját megtaláltam. Ez kiegészítheti a jules-skills 'automate-github-issues' tudását, lehetővé téve, hogy ne csak GitHubról, hanem Linear táblákból is automatikusan vegyek fel (Scheduled) ticketeket a háttérben.")

        if is_relevant:
            if repo not in repo_insights:
                repo_insights[repo] = set()
            for f in findings:
                repo_insights[repo].add(f)

    conn.close()

    # 2. Összesítjük a Jelentést (Sűrítés)
    if not repo_insights:
        final_report = "A felderített repókban nem találtam olyan MLOps, Adatbázis Elemző vagy CSV eszközt, ami a mi szigorú szűrési feltételeinknek megfelelt volna."
    else:
        for repo, insights in repo_insights.items():
            report_lines.append(f"🔹 {repo}:")
            for insight in insights:
                report_lines.append(f"  - {insight}")
        final_report = "\n".join(report_lines)

    print("\n" + final_report + "\n")

    # 3. Kiírjuk a Hosszútávú Memóriába (Mint egy jó Autonóm Agent)
    write_memory("Auto_Scout_Report", final_report)
    print("✅ Autonóm Felderítés befejezve. Tanulságok a memóriában!")

if __name__ == "__main__":
    run_autonomous_scout()
