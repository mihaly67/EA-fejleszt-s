# Experimental TradingView Advanced Charting

To run the local experimental TradingView frontend, which visualizes live data using the `charting_library`, run the following script:

```bash
./start_tv_frontend.sh
```

**Prerequisites:**

You must manually place the `charting_library` folder into `HUD_Development/tv_frontend/`. The codebase contains a dummy `charting_library.standalone.js` file to satisfy the pre-commit checks, but you must replace the folder with the legitimate TradingView library folder.

The HTTP server will listen on `127.0.0.1:8000` (accessible via `localhost:8000` in the browser on the VPS).
The WebSocket server will listen on `127.0.0.1:8765`.
