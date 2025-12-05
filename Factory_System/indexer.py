import os, json
def index_folder(folder):
    docs = []
    for root, dirs, files in os.walk(folder):
        for file in files:
            if file.endswith(('.mqh', '.mq5', '.h', '.cpp', '.py', '.txt', '.md')):
                try:
                    path = os.path.join(root, file)
                    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        if len(content) > 100:
                            docs.append({
                                'filename': file,
                                'path': path,
                                'content': content,
                                'search_content': content
                            })
                except: pass
    with open('new_knowledge_adatok.json', 'w') as f:
        json.dump(docs, f)
    print(f"Indexed {len(docs)} files.")

index_folder('new_knowledge')
