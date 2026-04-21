#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 1.0 (Knowledge Harvester - Extracting Gold from Mud)
import sys
import json
import os
import re

def clean_text(text):
    return text.replace('\r', '')

def extract_code_blocks(content):
    """Extracts content between ``` markers OR MQL5/C++ style blocks."""
    # Markdown blocks
    pattern_md = r"```(?:\w+)?\n(.*?)```"
    matches = re.findall(pattern_md, content, re.DOTALL)

    # RAG chunks might lack markdown but contain raw code.
    # Look for { ... } blocks with typical C++/MQL syntax if no markdown found
    if not matches and ("{" in content and "}" in content):
        # Very naive block extractor for C-like languages
        # Finds largest bracketed block? No, just treat whole chunk as potential code
        # if it looks very code-heavy (lots of semicolons and braces)
        semicolons = content.count(';')
        braces = content.count('{')
        if semicolons > 5 and braces > 2:
            matches.append(content)

    return [m.strip() for m in matches if len(m.strip()) > 20]

def is_highly_technical(content):
    """Simple heuristic to detect if a text block is worth saving."""
    keywords = ["class ", "def ", "function ", "import ", "struct ", "void ", "#include", "input ", "double ", "int ", "bool ", "string "]
    return any(k in content for k in keywords)

def harvest(json_files, output_file):
    print(f"🌾 Harvesting Knowledge from {len(json_files)} levels...")

    knowledge_vault = {} # topic -> list of snippets

    for filename in json_files:
        if not os.path.exists(filename): continue

        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
            results = data.get('results', [])

            for res in results:
                topic = res.get('parent_query', 'Uncategorized')
                content = clean_text(res.get('content', ''))
                filename = res.get('filename', '?')

                # 1. Extract Code Blocks
                blocks = extract_code_blocks(content)
                if blocks:
                    if topic not in knowledge_vault: knowledge_vault[topic] = []
                    for b in blocks:
                        knowledge_vault[topic].append({
                            'type': 'CODE',
                            'file': filename,
                            'content': b
                        })

                # 2. Extract Technical Paragraphs (if no code blocks found but looks technical)
                elif is_highly_technical(content):
                    if topic not in knowledge_vault: knowledge_vault[topic] = []
                    knowledge_vault[topic].append({
                        'type': 'TECHNICAL_NOTE',
                        'file': filename,
                        'content': content[:1000] + ("..." if len(content)>1000 else "")
                    })

    # Generate Markdown Report
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# 🏆 HARVESTED KNOWLEDGE VAULT\n\n")
        f.write(f"Generated from: {', '.join([os.path.basename(x) for x in json_files])}\n\n")

        for topic, snippets in knowledge_vault.items():
            f.write(f"## 🔑 Topic: {topic}\n\n")

            for i, snip in enumerate(snippets):
                icon = "💻" if snip['type'] == 'CODE' else "📝"
                f.write(f"### {icon} Snippet {i+1} (Source: {snip['file']})\n")
                if snip['type'] == 'CODE':
                    f.write("```\n" + snip['content'] + "\n```\n\n")
                else:
                    f.write("> " + snip['content'].replace('\n', '\n> ') + "\n\n")

            f.write("---\n\n")

    print(f"✅ Harvest complete. Saved to {output_file}")

if __name__ == "__main__":
    files = [
        "KUTATO_FEJLESZTES/KutatoIntezet/level_0.json",
        "KUTATO_FEJLESZTES/KutatoIntezet/level_1.json",
        "KUTATO_FEJLESZTES/KutatoIntezet/level_2.json"
    ]
    harvest(files, "KUTATO_FEJLESZTES/KutatoIntezet/HARVESTED_KNOWLEDGE.md")
