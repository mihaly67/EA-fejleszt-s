import chromadb
from chromadb.utils import embedding_functions
import os
import sys

def main():
    print("=== 🕵️ SWAT RAG QUERY SYSTEM ===")

    # Configuration
    db_path = "Knowledge_Base/SWAT_DB"
    collection_name = "swat_unified_knowledge"
    model_name = "all-MiniLM-L6-v2"
    query_text = "How to hook GetCursorPos and hardware IDs using Frida in MT5 under WINE?"

    # Check if DB exists
    if not os.path.exists(db_path):
        print(f"❌ Error: Database path '{db_path}' not found.")
        sys.exit(1)

    print(f"🔌 Connecting to ChromaDB at: {db_path}")

    try:
        # Initialize Embedding Function
        print(f"🧠 Loading Embedding Model: {model_name}...")
        ef = embedding_functions.SentenceTransformerEmbeddingFunction(model_name=model_name)

        # Initialize Client
        client = chromadb.PersistentClient(path=db_path)

        # Get Collection
        print(f"📂 Accessing Collection: {collection_name}...")
        try:
            collection = client.get_collection(name=collection_name, embedding_function=ef)
        except ValueError:
            print(f"❌ Error: Collection '{collection_name}' not found in the database.")
            # List available collections to be helpful
            cols = client.list_collections()
            print(f"   Available collections: {[c.name for c in cols]}")
            sys.exit(1)

        # Execute Query
        print(f"🔍 Executing Query: '{query_text}'")
        results = collection.query(
            query_texts=[query_text],
            n_results=3
        )

        # Display Results
        print("\n=== 🎯 SEARCH RESULTS ===\n")

        if not results['documents'][0]:
            print("⚠️ No results found.")
        else:
            for i, doc in enumerate(results['documents'][0]):
                meta = results['metadatas'][0][i] if results['metadatas'] else {}
                dist = results['distances'][0][i] if results['distances'] else "N/A"

                print(f"--- Result {i+1} (Distance: {dist}) ---")
                print(f"📄 Source: {meta.get('source', 'Unknown')}")
                print(f"Cx Context: {meta.get('context', 'N/A')}")
                print(f"📝 Content Snippet:\n{doc[:500]}...") # Limit output length
                print("-" * 50)

    except Exception as e:
        print(f"❌ An error occurred: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
