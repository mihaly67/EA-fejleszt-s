import re

with open("Knowledge_Base/agent_memory.jsonl", "r", encoding="utf-8") as f:
    content = f.read()

# Eltávolítjuk a GitHub PAT kulcsokat a fájlból, mert a GitHub Secret Scanning blokkolja a push-t!
content = re.sub(r'ghp_[a-zA-Z0-9]+', '[REDACTED_GITHUB_PAT]', content)

with open("Knowledge_Base/agent_memory.jsonl", "w", encoding="utf-8") as f:
    f.write(content)

