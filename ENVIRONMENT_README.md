# Environment & Search Architecture

## 1. Data Storage Layout
| Knowledge Base | Description | Storage Mode | Location |
| :--- | :--- | :--- | :--- |
| **THEORY_RAG** | MQL5 Books & Theory | **RAM** (Index + Data) | `rag_theory/` |
| **CODEBASE_RAG** | Code Snippets | **DISK** (SQLite + MMAP) | `rag_code/` |
| **MQL5_DEV_RAG** | Articles & Big Data | **DISK** (SQLite + MMAP) | `rag_mql5_dev/` |

## 2. Scripts
- **`restore_environment.py`**: The Master Script.
  - Checks if databases exist and are valid.
  - Downloads missing parts from Google Drive (IDs verified).
  - Handles renaming (`rag_mql5` -> `rag_mql5_dev`) and cleanup.
  - Updates `.gitignore`.

- **`kutato.py`**: The Unified Search Engine.
  - Automatically loads Theory into RAM for speed.
  - Connects to Disk-based DBs for Code/MQL5 to save RAM.
  - Use: `python3 kutato.py "query" --scope ALL`

## 3. Session Startup
In a new session, simply run:
```bash
python3 restore_environment.py
```
This will restore the state in seconds if files persist, or download them if missing.
