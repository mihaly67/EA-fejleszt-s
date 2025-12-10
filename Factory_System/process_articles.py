
import os
import zipfile
import glob
import re
import json
import shutil
import chardet
from bs4 import BeautifulSoup

# --- CONFIGURATION ---
INPUT_DIR = "Res/Articles/Raw/Jules cikk és fájl letöltés"
OUTPUT_DIR = "Res/Articles/Processed_Structured"

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def read_file_content(file_path):
    """Robust file reader handling various encodings"""
    try:
        # Try UTF-8 first (fastest)
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except UnicodeDecodeError:
        try:
            # Detect encoding
            with open(file_path, 'rb') as f:
                raw_data = f.read(10000) # Read enough for detection

            result = chardet.detect(raw_data)
            encoding = result['encoding']

            if encoding:
                with open(file_path, 'r', encoding=encoding, errors='replace') as f:
                    return f.read()
        except:
            pass

    # Fallback to Latin-1/Replace
    try:
        with open(file_path, 'r', encoding='latin-1', errors='replace') as f:
            return f.read()
    except Exception as e:
        return f"[Read Error: {e}]"

# --- INTELLIGENT CLASSIFICATION ---
def categorize_article(title):
    t = title.lower()
    if "machine learning" in t or "neural network" in t or " python " in t or " ai " in t:
        return "Machine_Learning_AI"
    if "strategy" in t or "system" in t or "trading" in t:
        return "Trading_Strategies"
    if "indicator" in t or "oscillat" in t:
        return "Indicators"
    if "standard library" in t or "library" in t:
        return "Standard_Library"
    if "visualization" in t or "gui" in t or "panel" in t or "dashboard" in t:
        return "GUI_Visualization"
    return "General_MQL5"

def detect_series(title):
    # Matches: "Title (Part 4)" or "Title Part 4" or "Title (4)" or "Title I" (Roman not handled yet, assume digit)
    match = re.search(r'[\(\s](Part\s*)?(\d+)[\)\:]', title, re.IGNORECASE)
    if match:
        part_num = int(match.group(2))
        # Remove the part string to get the base series name
        # This is rough but useful for grouping
        series_name = re.sub(r'[\(\s]Part\s*\d+[\)\:]', '', title).strip()
        return series_name, part_num
    return None, None

# --- EXTRACTION LOGIC ---
def extract_text_from_html(html_path):
    try:
        html_content = read_file_content(html_path)
        soup = BeautifulSoup(html_content, 'html.parser')

        # 1. Title
        title = "Unknown Title"
        title_tag = soup.find('h1') or soup.find('title')
        if title_tag:
            title = title_tag.get_text(strip=True)
            # Remove "- MQL5 Articles" suffix if present
            title = title.replace("- MQL5 Articles", "").strip()

        # 2. Body Processing
        content = []
        article_body = soup.find('div', id='articleContent') or \
                       soup.find('div', class_='text') or \
                       soup.find('div', class_='content') or \
                       soup.find('div', itemprop='articleBody')

        if not article_body:
            first_h1 = soup.find('h1')
            if first_h1:
                article_body = first_h1.parent
            else:
                return title, "Error: Could not parse article body (No container found)."

        for element in article_body.find_all(['p', 'h1', 'h2', 'h3', 'h4', 'pre', 'code', 'ul', 'ol']):
            if element.name in ['h1', 'h2', 'h3', 'h4']:
                content.append(f"\n\n### {element.get_text(strip=True)} ###\n")
            elif element.name == 'p':
                content.append(element.get_text(strip=True))
            elif element.name in ['pre', 'code']:
                code_text = element.get_text()
                content.append(f"\n```\n{code_text}\n```\n")
            elif element.name in ['ul', 'ol']:
                for li in element.find_all('li'):
                    content.append(f" - {li.get_text(strip=True)}")

        return title, "\n".join(content)
    except Exception as e:
        return None, f"Error parsing HTML: {e}"

def extract_code_from_zip(zip_path):
    code_contents = []
    try:
        temp_extract_path = zip_path + "_extracted"
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(temp_extract_path)

        for root, dirs, files in os.walk(temp_extract_path):
            for file in files:
                if file.endswith(('.mq5', '.mqh', '.py', '.cpp', '.h', '.csv', '.txt')):
                    file_path = os.path.join(root, file)
                    try:
                        c = read_file_content(file_path)
                        rel_path = os.path.relpath(file_path, temp_extract_path)
                        code_contents.append(f"\n\n--- FILE: {rel_path} ---\n\n{c}")
                    except:
                        pass
    except Exception as e:
        code_contents.append(f"\n[Error extracting zip: {e}]")
    finally:
        if os.path.exists(temp_extract_path):
            try:
                shutil.rmtree(temp_extract_path)
            except:
                pass

    return "".join(code_contents)

def process_single_article(html_file):
    base_name = os.path.splitext(os.path.basename(html_file))[0]
    article_id_match = re.search(r'(\d+)', base_name)
    zip_file = None
    article_id = "?"

    if article_id_match:
        article_id = article_id_match.group(1)
        input_dir = os.path.dirname(html_file)
        # Match pattern article_ID__ID.zip OR just article_ID.zip
        candidates = glob.glob(os.path.join(input_dir, f"*{article_id}*.zip"))
        if candidates:
            zip_file = candidates[0]

    print(f"Processing: {base_name} (ID: {article_id})")

    # 1. Extract Content
    title, text_content = extract_text_from_html(html_file)

    # 2. Extract Code
    code_content = ""
    if zip_file:
        print(f"  Found Zip: {os.path.basename(zip_file)}")
        code_content = extract_code_from_zip(zip_file)

    # 3. Intelligent Metadata
    category = categorize_article(title)
    series_name, part_num = detect_series(title)

    metadata = {
        "id": article_id,
        "title": title,
        "category": category,
        "series": series_name,
        "part": part_num,
        "filename": base_name
    }

    # 4. Construct Output
    # We add a JSON header line for easy parsing by the Vectorizer
    json_header = json.dumps(metadata, ensure_ascii=False)

    full_content = f"METADATA_JSON: {json_header}\n\n" \
                   f"TITLE: {title}\n" \
                   f"CATEGORY: {category}\n" \
                   f"SERIES: {series_name if series_name else 'None'} (Part {part_num if part_num else 'N/A'})\n\n" \
                   f"=== ARTICLE TEXT ===\n\n{text_content}\n\n" \
                   f"=== ATTACHED CODEBASE ===\n{code_content}"

    # 5. Save to Category Subfolder
    target_folder = os.path.join(OUTPUT_DIR, category)
    ensure_dir(target_folder)

    # Filename: If series, maybe prefix?
    # For now, keep ID but put in folder.
    # Optional: "Part_04_Article_20266.txt" to sort by name?
    # Let's keep it simple: "article_20266.txt"
    output_filename = f"processed_{base_name}.txt"
    output_path = os.path.join(target_folder, output_filename)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(full_content)

    print(f"  Saved to: {output_path}")

def main():
    if not os.path.exists(INPUT_DIR):
        print(f"Input directory not found: {INPUT_DIR}")
        return

    html_files = glob.glob(os.path.join(INPUT_DIR, "*.html"))
    print(f"Found {len(html_files)} articles to process.")

    for html in html_files:
        process_single_article(html)

    print("\nProcessing Complete. Check folder: " + OUTPUT_DIR)

if __name__ == "__main__":
    main()
