# Development Standards & Rules

## File Naming & Versioning
*   **STRICT RULE:** All MQL5 indicator source files (`.mq5`) **MUST** include the version number in their filename.
    *   *Correct:* `HybridMomentumIndicator_v2.6.mq5`
    *   *Incorrect:* `HybridMomentumIndicator.mq5`
*   Do not rely solely on `#property version` inside the code. The filename is the primary identifier to prevent confusion.
*   When updating an indicator, **always** create a new file with the incremented version number (e.g., `v2.2` -> `v2.3`) unless specifically explicitly told otherwise.

## Code Conventions
*   **Colors:** Use the "Soft Professional Palette" to avoid eye strain.
    *   Up/Positive: `clrForestGreen`
    *   Down/Negative: `clrFireBrick`
    *   Neutral/Filtered: `clrGray` or `clrSilver`
    *   Ticks/Volume: `clrDarkGoldenrod`
*   **Visualization:**
    *   Use `DRAW_COLOR_HISTOGRAM` or `DRAW_COLOR_LINE` where possible to support the native MT5 "Colors" tab.
    *   Always expose boolean visibility inputs (e.g., `InpShowHybrid`) for composite indicators.

## Workflow
*   **Verification:** Always visually verify changes (or ask the user to) before finalizing.
*   **Handover:** Save session notes to `LAST_SESSION_HANDOVER_YYYY_MM_DD.md`.
