import os
import json
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# --- KÖZPONTI KONFIGURÁCIÓ ---
# Itt fogjuk legenerálni az optimális JSONL fájlt a RAG-hoz.
OUTPUT_FILE = "ai_restoration_data.jsonl"
OUTPUT_ZIP = "video_picture_restoration_knowledge.zip"
OUTPUT_LIST = "processed_repos.txt"

# Kód, konfiguráció és dokumentáció kiterjesztések
# FIGYELEM: A média fájlokat (jpg, png, mp4, wav, stb.) SZIGORÚAN KIZÁRJUK!
VALID_EXTENSIONS = {
    # Python ökoszisztéma (A gépi tanulás alapja)
    '.py', '.pyx', '.pxd', '.ipynb',
    # C/C++ / CUDA (Gyorsítás, VapourSynth, MMCV, PyTorch)
    '.c', '.cpp', '.h', '.hpp', '.cc', '.cxx', '.cu', '.cuh',
    # C# / GUI (Pl. Waifu2x-Extension-GUI)
    '.cs', '.xaml',
    # Config és strukturált adatok
    '.json', '.yaml', '.yml', '.toml', '.ini', '.cfg',
    # Dokumentáció és leírások
    '.md', '.rst', '.txt',
    # Web / Frontend Interfész (Gradio, React, Vue stb.)
    '.js', '.ts', '.jsx', '.tsx', '.vue', '.svelte', '.html', '.css', '.scss',
    # Shell / Scripting
    '.sh', '.bash', '.zsh', '.bat', '.ps1'
}

# Kizárandó könyvtárak (Hatalmas felesleges bloat)
IGNORE_DIRS = {
    '.git', '.github', 'node_modules', '__pycache__', 'venv', 'env',
    'dist', 'build', 'target', '.idea', '.vscode', 'checkpoints',
    'weights', 'models', 'pretrained', 'tmp', 'temp', 'logs',
    'samples', 'images', 'results', 'datasets'
}

MAX_FILE_SIZE = 2 * 1024 * 1024  # 2 MB max per fájl, hogy ne terheljük a memóriát/RAG-ot

def get_script_dir():
    return os.path.dirname(os.path.abspath(__file__))

def get_repo_folders(base_path):
    repo_dirs = []
    print(f"🔍 Repók keresése a könyvtárban: {base_path}")
    try:
        with os.scandir(base_path) as entries:
            for entry in entries:
                if entry.is_dir() and entry.name not in IGNORE_DIRS and not entry.name.startswith('.'):
                     repo_dirs.append(entry.name)
    except OSError as e:
        print(f"❌ Hiba a könyvtár olvasásakor: {e}")
    return sorted(repo_dirs)

def is_text_file(filepath):
    """Gyors ellenőrzés, hogy a fájl valószínűleg olvasható szöveg-e (nem bináris)."""
    try:
        with open(filepath, 'tr', encoding='utf-8') as check_file:
            check_file.read(1024)
            return True
    except UnicodeDecodeError:
        try:
            with open(filepath, 'tr', encoding='latin-1') as check_file:
                 check_file.read(1024)
                 return True
        except:
             return False
    except Exception:
        return False

def get_programming_language(ext):
    """Visszaadja a nyelv/típus címkéjét kiterjesztés alapján a hatékony RAG szűréshez."""
    mapping = {
        '.py': 'Python', '.ipynb': 'Jupyter',
        '.c': 'C', '.cpp': 'C++', '.cu': 'CUDA', '.h': 'C/C++ Header',
        '.cs': 'C#', '.xaml': 'XAML',
        '.js': 'JavaScript', '.ts': 'TypeScript', '.jsx': 'React JSX', '.tsx': 'React TSX',
        '.vue': 'Vue', '.svelte': 'Svelte', '.html': 'HTML', '.css': 'CSS', '.scss': 'SCSS',
        '.json': 'JSON', '.yaml': 'YAML', '.yml': 'YAML', '.toml': 'TOML',
        '.md': 'Markdown', '.txt': 'Text',
        '.sh': 'Shell', '.bat': 'Batch'
    }
    return mapping.get(ext, 'Unknown')

def process_single_file(filepath):
    """
    Sokkal strukturáltabb, RAG-ra optimalizált adatstruktúrát generál.
    Később a RAG DB-ben könnyen lehet "type" vagy "language" alapján szűrni.
    """
    ext = os.path.splitext(filepath)[1].lower()
    if ext not in VALID_EXTENSIONS:
        return None

    if os.path.getsize(filepath) > MAX_FILE_SIZE:
        return None

    if not is_text_file(filepath):
        return None

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        try:
            with open(filepath, 'r', encoding='latin-1') as f:
                content = f.read()
        except:
            return None

    if not content.strip():
        return None

    # Útvonal felbontása (Repo -> Almappák -> Fájl)
    script_dir = get_script_dir()
    rel_path = os.path.relpath(filepath, script_dir)
    parts = Path(rel_path).parts
    source_repo = parts[0] if parts else "Unknown"

    # Metaadatok összeállítása
    file_type = "Documentation" if ext in ['.md', '.rst', '.txt'] else "Code"
    if ext in ['.json', '.yaml', '.yml', '.toml', '.ini', '.cfg']:
        file_type = "Configuration"

    return {
        "metadata": {
            "source_repo": source_repo,
            "filepath": rel_path.replace("\\", "/"),
            "file_extension": ext,
            "language": get_programming_language(ext),
            "file_type": file_type,
            "size_bytes": len(content)
        },
        "content": content
    }

def collect_files_from_repos(base_path, repo_names):
    file_list = []
    print(f"\n📂 Feldolgozandó repók száma: {len(repo_names)}")

    for repo in repo_names:
        repo_path = os.path.join(base_path, repo)
        if not os.path.exists(repo_path): continue

        for root, dirs, files in os.walk(repo_path):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS and not d.startswith('.')]
            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext in VALID_EXTENSIONS:
                    file_list.append(os.path.join(root, file))

    print(f"✅ Összesen {len(file_list)} érvényes kód/doksi fájlt találtam (Média fájlok kizárva).")
    return file_list

def main():
    print("=== 🧠 AI PICTURE & VIDEO RESTORATION - STRUKTURÁLT KNOWLEDGE BUILDER ===")

    work_dir = get_script_dir()
    output_jsonl = os.path.join(work_dir, OUTPUT_FILE)
    output_zip = os.path.join(work_dir, OUTPUT_ZIP)
    output_list = os.path.join(work_dir, OUTPUT_LIST)

    repo_names = get_repo_folders(work_dir)
    if not repo_names:
        print("❌ Nem találtam könyvtárakat/repókat ebben a mappában.")
        return

    # Mentsük el a repók listáját
    with open(output_list, 'w', encoding='utf-8') as f:
        for repo in repo_names:
            f.write(repo + "\n")

    all_files = collect_files_from_repos(work_dir, repo_names)
    if not all_files:
        return

    print(f"🚀 Fájlok feldolgozása és JSONL strukturálása...")
    start_time = time.time()

    try:
        from tqdm import tqdm
        has_tqdm = True
    except ImportError:
        has_tqdm = False

    records = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        if has_tqdm:
            results = list(tqdm(executor.map(process_single_file, all_files), total=len(all_files), unit="fájl"))
        else:
            results = list(executor.map(process_single_file, all_files))

        records = [r for r in results if r is not None]

    print(f"💾 {len(records)} strukturált rekord írása...")
    with open(output_jsonl, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

    print(f"📦 Archívum létrehozása: {OUTPUT_ZIP}")
    with zipfile.ZipFile(output_zip, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.write(output_jsonl, arcname=OUTPUT_FILE)
        zf.write(output_list, arcname=OUTPUT_LIST)

    elapsed = time.time() - start_time
    print("\n=== ✅ KÉSZ ===")
    print(f"⏱️  Idő: {elapsed:.2f}s")
    print(f"📂 Kész ZIP csomag: {OUTPUT_ZIP} ({os.path.getsize(output_zip) / (1024*1024):.2f} MB)")
    print("👉 Ezt a JSONL/ZIP fájlt sokkal könnyebben és hatékonyabban fogja megérteni az új RAG DB Scripted!")

if __name__ == "__main__":
    main()
