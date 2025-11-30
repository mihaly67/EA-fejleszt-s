
import os
import zipfile
import glob
import re
from bs4 import BeautifulSoup

# --- CONFIGURATION ---
INPUT_DIR = "Res/Articles/Raw/Jules cikk és fájl letöltés" # Change this to your folder
OUTPUT_DIR = "Res/Articles/Processed"

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def extract_text_from_html(html_path):
    try:
        with open(html_path, 'r', encoding='utf-8', errors='ignore') as f:
            soup = BeautifulSoup(f, 'html.parser')

        # 1. Title
        title = "Unknown Title"
        title_tag = soup.find('h1') or soup.find('title')
        if title_tag:
            title = title_tag.get_text(strip=True)

        # 2. Body Processing
        # We iterate over paragraphs and code blocks to preserve flow
        content = []

        # This is a heuristic. MQL5 articles usually have a main div.
        # We'll target the common class or ID.
        article_body = soup.find('div', id='articleContent') or \
                       soup.find('div', class_='text') or \
                       soup.find('div', class_='content') or \
                       soup.find('div', itemprop='articleBody')

        if not article_body:
            # Fallback: Look for the first H1 and take its parent,
            # hoping the parent is the content wrapper.
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
                # Code block
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

        # Walk through extracted files
        for root, dirs, files in os.walk(temp_extract_path):
            for file in files:
                if file.endswith(('.mq5', '.mqh', '.py', '.cpp', '.h', '.csv', '.txt')):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                            c = f.read()
                            # Clean up path for display
                            rel_path = os.path.relpath(file_path, temp_extract_path)
                            code_contents.append(f"\n\n--- FILE: {rel_path} ---\n\n{c}")
                    except:
                        pass

        # Cleanup (Optional: keep or delete. Deleting to save space)
        # shutil.rmtree(temp_extract_path) # Need import shutil
    except Exception as e:
        code_contents.append(f"\n[Error extracting zip: {e}]")

    return "".join(code_contents)

def process_single_article(html_file):
    base_name = os.path.splitext(os.path.basename(html_file))[0]
    # Assume zip has format: article_ID__ID.zip or similar
    # The user provided example: article_20266.html -> article_20266__20266.zip

    # Try to find matching zip
    # Strategy: Look for zip files that contain the ID number from the HTML filename
    article_id_match = re.search(r'(\d+)', base_name)
    zip_file = None

    if article_id_match:
        article_id = article_id_match.group(1)
        # Look for zip containing this ID
        input_dir = os.path.dirname(html_file)
        candidates = glob.glob(os.path.join(input_dir, f"*{article_id}*.zip"))
        if candidates:
            zip_file = candidates[0] # Pick the first match

    print(f"Processing: {base_name} (ID: {article_id if article_id_match else '?'})")

    # 1. Extract Text
    title, text_content = extract_text_from_html(html_file)

    # 2. Extract Code (if zip exists)
    code_content = ""
    if zip_file:
        print(f"  Found Zip: {os.path.basename(zip_file)}")
        code_content = extract_code_from_zip(zip_file)
    else:
        print("  No matching zip found.")

    # 3. Combine
    full_content = f"TITLE: {title}\n\n=== ARTICLE TEXT ===\n\n{text_content}\n\n=== ATTACHED CODEBASE ===\n{code_content}"

    # 4. Save
    output_path = os.path.join(OUTPUT_DIR, f"processed_{base_name}.txt")
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(full_content)

    print(f"  Saved to: {output_path}")

def main():
    ensure_dir(OUTPUT_DIR)

    # Find all HTML files
    html_files = glob.glob(os.path.join(INPUT_DIR, "*.html"))

    if not html_files:
        print(f"No .html files found in {INPUT_DIR}")
        return

    print(f"Found {len(html_files)} articles to process.")

    for html in html_files:
        process_single_article(html)

    print("\nProcessing Complete.")

if __name__ == "__main__":
    main()
