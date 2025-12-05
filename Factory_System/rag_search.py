import sys
import json
import faiss
from sentence_transformers import SentenceTransformer

def search_knowledge_base(query, k=3):
    """
    Betölti a modellt és az indexet, majd keresést végez a tudásbázisban.
    """
    try:
        # 1. Modell és adatok betöltése
        model = SentenceTransformer('all-MiniLM-L6-v2')
        index = faiss.read_index('tudasbazis.index')
        with open('tudasbazis_adatok.json', 'r', encoding='utf-8') as f:
            data = json.load(f)

    except Exception as e:
        print(f"Hiba a modell vagy az adatbázis betöltése közben: {e}")
        return

    # 2. Keresés végrehajtása
    query_vector = model.encode([query])
    distances, indices = index.search(query_vector, k)

    # 3. Találatok feldolgozása és kiírása
    print(f"--- Keresési eredmények a \"{query}\" kifejezésre ---\n")
    for i in range(k):
        idx = indices[0][i]
        if idx < 0:
            continue

        result = data[idx]
        source = result.get("volume", "Ismeretlen forrás")
        content = result.get("original_text", "Nincs tartalom.")

        print(f"--- Találat #{i+1} | Forrás: {source} ---")
        print(content)
        print("\n" + "="*80 + "\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Használat: python rag_search.py \"<kérdés>\"")
    else:
        # Az argumentumokat egyetlen stringgé fűzzük össze
        user_query = " ".join(sys.argv[1:])
        search_knowledge_base(user_query)
