import gdown
import os

# File ID from the user's link
FILE_ID = "1--2Gl7qD8lBLmN8Wj-_rU0feVAfgCfSi"
OUTPUT_FILE = "Mimic_Research_Session_Data.csv"

def main():
    print(f"📥 Downloading CSV from Drive ID: {FILE_ID}...")

    # Using the standard Google Drive URL format for gdown
    url = f'https://drive.google.com/uc?id={FILE_ID}'

    try:
        gdown.download(url, OUTPUT_FILE, quiet=False)

        if os.path.exists(OUTPUT_FILE):
            size = os.path.getsize(OUTPUT_FILE) / 1024
            print(f"✅ Download Complete: {OUTPUT_FILE} ({size:.2f} KB)")

            # Quick Peek
            with open(OUTPUT_FILE, 'r', errors='ignore') as f:
                header = f.readline().strip()
                line1 = f.readline().strip()
                print("\n👀 Header Preview:")
                print(header)
                print("\n👀 First Row Preview:")
                print(line1)
        else:
            print("❌ Download failed (File not found).")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()
