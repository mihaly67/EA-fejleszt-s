#!/bin/bash
set -e

echo "=== RAG Knowledge Base Setup ==="
echo "Mode: Disk-Based (MMAP + SQLite)"
echo "--------------------------------"

# Check dependencies
if ! command -v gdown &> /dev/null; then
    echo "Installing gdown..."
    pip install gdown
fi

# Function to download, extract, hoist, and clean
setup_rag() {
    NAME=$1
    ID=$2
    TARGET_DIR=$3
    CHECK_FILE=$4

    echo "[*] Processing $NAME..."

    # Cleanup previous
    rm -rf "$TARGET_DIR"
    mkdir -p "$TARGET_DIR"

    # Download
    echo "    -> Downloading from Drive..."
    gdown --fuzzy "$ID" -O "${NAME}.zip"

    # Extract
    TMP_DIR="_tmp_${NAME}"
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    echo "    -> Extracting..."
    unzip -q "${NAME}.zip" -d "$TMP_DIR"

    # Hoist
    echo "    -> Locating content..."
    FOUND=$(find "$TMP_DIR" -name "$CHECK_FILE" | head -n 1)
    if [ -z "$FOUND" ]; then
        echo "ERROR: Critical file $CHECK_FILE not found in archive."
        exit 1
    fi
    SOURCE_DIR=$(dirname "$FOUND")

    echo "    -> Moving files to $TARGET_DIR..."
    shopt -s dotglob
    mv "$SOURCE_DIR"/* "$TARGET_DIR"/
    shopt -u dotglob

    # Cleanup
    echo "    -> Cleaning up..."
    rm "${NAME}.zip"
    rm -rf "$TMP_DIR"

    echo "    -> $NAME installed successfully."
}

# 1. Theory RAG (Small)
# Link: https://drive.google.com/file/d/1T0etzQc1bdT89X67sa3zMbuZNZWM-Anv
setup_rag "rag_theory" "1T0etzQc1bdT89X67sa3zMbuZNZWM-Anv" "rag_theory" "theory_knowledgebase.db"

# 2. Code RAG (Small)
# Link: https://drive.google.com/file/d/1CmoE49YTc_-dxyn4EiYyIDHINENeT5KI
setup_rag "rag_code" "1CmoE49YTc_-dxyn4EiYyIDHINENeT5KI" "rag_code" "code_knowledgebase.db"

# 3. MQL5 Dev RAG (Large)
# Link: https://drive.google.com/file/d/1gMumIUSdXuUlHJuymbWE8GwAd5K7ruSy
# Note: User provided this link for the full package.
setup_rag "rag_mql5" "1gMumIUSdXuUlHJuymbWE8GwAd5K7ruSy" "rag_mql5" "MQL5_DEV_knowledgebase.db"

echo "=== Setup Complete ==="
ls -F rag_*/
