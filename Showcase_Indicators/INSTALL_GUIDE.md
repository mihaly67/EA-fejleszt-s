# MQL5 Installation Guide (Updated)

To ensure the "Hybrid Scalper" system works correctly, please install the files into the following directories within your MetaTrader 5 Data Folder (File -> Open Data Folder).

## 1. Libraries (Headers)
*   **File:** `Amplitude_Booster.mqh`
*   **Path:** `MQL5/Include/Amplitude_Booster.mqh`
    *   *Alternative:* You can create a subfolder like `MQL5/Include/Jules/` and move it there, but you must update the `#include` lines in the other files.

## 2. Indicators
*   **File:** `Hybrid_MTF_Scalper.mq5`
*   **Path:** `MQL5/Indicators/Hybrid_MTF_Scalper.mq5`
*   **Compilation:** Open this file in MetaEditor and press **F7** (Compile). It requires `Amplitude_Booster.mqh` to be present in the Include folder (or the same folder).

## 3. Scripts (Testing)
*   **File:** `Test_Amplitude_Booster.mq5`
*   **Path:** `MQL5/Scripts/Test_Amplitude_Booster.mq5`
*   **Compilation:** Open this file in MetaEditor and press **F7**. Run it on a chart to verify the library logic in the "Experts" log tab.

## Troubleshooting
*   **"cannot open include file":** The compiler cannot find `Amplitude_Booster.mqh`. Ensure it is in `MQL5/Include/` or the same folder as the mq5 file.
*   **"event handling function not found":** You are trying to compile the `.mqh` file directly. Do not compile `.mqh` files. Compile the `.mq5` files instead.
