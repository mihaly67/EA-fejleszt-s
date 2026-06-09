from playwright.sync_api import sync_playwright
import time
import os

def record_hud_video():
    # Biztosítjuk, hogy a kimeneti mappa létezik
    os.makedirs("video_output", exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Beállítjuk a videó rögzítési mappáját
        context = browser.new_context(record_video_dir="video_output", record_video_size={"width": 1280, "height": 720})
        page = context.new_page()

        print("Megnyitom a Streamlit HUD oldalt...")
        page.goto("http://5.189.163.88:8501")

        print("Várunk 60 másodpercet, hogy a HUD működését rögzítsük...")
        time.sleep(60) # 1 perces videó

        print("Felvétel leállítása és mentése...")
        page.close()
        context.close()
        browser.close()

if __name__ == "__main__":
    record_hud_video()
