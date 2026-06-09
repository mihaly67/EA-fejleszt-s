from playwright.sync_api import sync_playwright
import time
import os
import shutil

def record_hud_video(duration=180, filename="hud_diagnostics_extended.webm"):
    # Biztosítjuk, hogy a kimeneti mappa létezik
    os.makedirs("video_output", exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Beállítjuk a videó rögzítési mappáját
        context = browser.new_context(record_video_dir="video_output", record_video_size={"width": 1280, "height": 720})
        page = context.new_page()

        print("Megnyitom a Streamlit HUD oldalt...")
        page.goto("http://5.189.163.88:8501")

        print(f"Várunk {duration} másodpercet, hogy a HUD működését rögzítsük...")
        time.sleep(duration) # hosszabb videó

        print("Felvétel leállítása és mentése...")

        video_path = page.video.path()

        page.close()
        context.close()
        browser.close()

        print(f"Mentés a végső helyre: {filename}")
        shutil.move(video_path, f"HMM_Pipe_HUD/{filename}")

if __name__ == "__main__":
    record_hud_video(180, "hud_diagnostics_extended_1.webm")
    record_hud_video(180, "hud_diagnostics_extended_2.webm")
