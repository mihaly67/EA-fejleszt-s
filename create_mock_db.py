import sqlite3
import faiss
import numpy as np
import os
from sentence_transformers import SentenceTransformer

def create_mock_db():
    db_dir = "Knowledge_Base/SWAT_DB"
    os.makedirs(db_dir, exist_ok=True)
    db_path = os.path.join(db_dir, "swat_unified.db")
    index_path = os.path.join(db_dir, "swat_unified_compressed.index")

    # 1. SQLite létrehozása régi sémával (swat_data)
    if os.path.exists(db_path): os.remove(db_path)
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute('''CREATE TABLE swat_data (
                    id INTEGER PRIMARY KEY,
                    source TEXT,
                    content TEXT)''')

    # Mock adatok (HMM példa 3 részletben)
    mock_data = [
        ("ML_Ops/hmm_model.py", "import numpy as np\nfrom hmmlearn import hmm\n\n# HMM konfiguráció"),
        ("ML_Ops/hmm_model.py", "def init_model():\n    model = hmm.GaussianHMM(n_components=3, covariance_type='diag')\n    return model"),
        ("ML_Ops/hmm_model.py", "def train_model(model, data):\n    model.fit(data)\n    print('Training complete')")
    ]

    for i, (source, content) in enumerate(mock_data):
        c.execute("INSERT INTO swat_data (id, source, content) VALUES (?, ?, ?)", (i, source, content))
    conn.commit()
    conn.close()

    # 2. FAISS Index létrehozása
    print("Vektorizálás...")
    model = SentenceTransformer("all-MiniLM-L6-v2")
    dim = getattr(model, "get_embedding_dimension", lambda: getattr(model, "get_sentence_embedding_dimension")())()
    index = faiss.IndexIDMap(faiss.IndexFlatL2(dim))

    embeddings = model.encode([content for _, content in mock_data]).astype('float32')
    index.add_with_ids(embeddings, np.array([0, 1, 2]).astype('int64'))

    faiss.write_index(index, index_path)
    print("Mock RAG kész!")

if __name__ == "__main__":
    create_mock_db()
