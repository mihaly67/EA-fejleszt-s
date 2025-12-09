# Dashboard Control Center Specification

## 1. Concept: The "Cockpit"
The panel is not just a display; it is an Input Device. It allows the trader to "Conduct" the algorithm.

## 2. Layout & Controls (Wireframe)

### 2.1 Header Row (Status)
- **Label:** `System Status: [ AUTO / MANUAL / HYBRID ]`
- **Indicator:** Green/Red LED for "Python Connection".

### 2.2 Mode Switches (Toggle Buttons)
- `[ SL: AUTO ]` vs `[ SL: MANUAL ]` (Click to toggle)
- `[ TP: AUTO ]` vs `[ TP: MANUAL ]`
- `[ ENTRY: ASSISTANT ]` vs `[ ENTRY: FULL AUTO ]`

### 2.3 Risk Controls (Sliders/Inputs)
- **Risk %:** Slider [0.5% -----|----- 5.0%]
- **Conviction Thresh:** Slider [Low --|-- High] (Filter weak signals)

### 2.4 Action Buttons (Panic/Tactical)
- `[ CLOSE ALL ]`: Liquidate everything immediately.
- `[ FLATTEN BUY ]`: Close only Buys.
- `[ FREEZE ]`: Disable all new entries, manage existing.

### 2.5 Information Deck (The "Verbose" View)
- **Box:** Scrolling text log.
- **Content:**
    - "Trend Up (ADX 35). Python Filter confirms."
    - "Risk reduced due to High Volatility (TickSD > 0.005)."
    - "News Event in 15 mins. Entries Blocked."

## 3. Implementation Patterns
- Use `CAppDialog` base.
- Custom `CButton` subclasses for "Toggle" behavior (maintaining state).
- `CSlider` or `CSpinEdit` for numeric inputs.
- Event Handling: `ON_CLICK` events route directly to `CProfitManager::SetMode(...)`.
