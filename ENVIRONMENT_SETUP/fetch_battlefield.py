import gdown
import os

FILE_ID = "1hLkibxtDXE3Db4m6vgpbFNxBHHoEBFV4"
OUTPUT_FILE = "Mimic_Research_Battlefield.csv"

def main():
    print(f"📥 Downloading Battlefield CSV from Drive ID: {FILE_ID}...")
    url = f'https://drive.google.com/uc?id={FILE_ID}'

    try:
        gdown.download(url, OUTPUT_FILE, quiet=False)

        if os.path.exists(OUTPUT_FILE):
            size = os.path.getsize(OUTPUT_FILE) / (1024*1024)
            print(f"✅ Download Complete: {OUTPUT_FILE} ({size:.2f} MB)")

            # Peek
            with open(OUTPUT_FILE, 'r', errors='ignore') as f:
                header = f.readline().strip()
                print("\n👀 Header Preview:")
                print(header[:200] + "...")
        else:
            print("❌ Download failed.")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()
