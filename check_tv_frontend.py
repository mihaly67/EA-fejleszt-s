from playwright.sync_api import sync_playwright

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        def handle_console(msg):
            print(f"[{msg.type}] Console: {msg.text}")

        page.on("console", handle_console)
        page.on("pageerror", lambda err: print(f"[Page Error] {err.message}"))

        print("Navigating to http://localhost:8000...")
        try:
            page.goto("http://localhost:8000", wait_until="networkidle", timeout=10000)
            print("Page loaded.")
            # wait a bit for any JS execution
            page.wait_for_timeout(2000)
        except Exception as e:
            print(f"Error during navigation: {e}")

        browser.close()

if __name__ == "__main__":
    main()
