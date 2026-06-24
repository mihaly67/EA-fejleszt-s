# Communication & Remote Control Specification

## 1. Overview
The **Communication Module** enables the EA to "talk" to the user and the user to "command" the EA remotely.
- **Primary Goal:** Real-time alerts (Trade Opened/Closed, Risk Warning).
- **Secondary Goal:** Remote Control ("Emergency Close", "Switch to Manual") via Mobile.

## 2. Channels

### 2.1 Telegram Bot (Two-Way)
- **Role:** The main interface for remote interaction.
- **Features:**
    - **Alerts:** Rich text messages with emojis (e.g., 🔴 Sell EURUSD, 🟢 Buy Gold).
    - **Screenshots:** Send chart screenshot on entry/exit.
    - **Control:** Inline Buttons in chat (e.g., `[CLOSE ALL]`, `[PAUSE EA]`).
- **Implementation:**
    - Uses `WebRequest` to `api.telegram.org`.
    - Requires `BotToken` and `ChatID` inputs.
    - Polling loop (Timer) to check for incoming commands (`getUpdates`).

### 2.2 Native Push (One-Way)
- **Role:** Redundant backup for critical alerts.
- **Features:** Instant delivery to MetaTrader Mobile App.
- **Implementation:** `SendNotification()`.

### 2.3 Discord (Optional)
- **Role:** Logging / Community broadcast.
- **Implementation:** Webhook (`WebRequest` POST JSON).

## 3. Class Design: `CCommunicationManager`
Acts as the central hub. The `TradingAssistant` sends events here.

### 3.1 Interface
```mql5
class CCommunicationManager {
public:
    void SendAlert(string message, ENUM_ALERT_PRIORITY priority);
    void SendScreenshot(long chart_id);
    void ProcessRemoteCommands(); // Called on Timer
};
```

### 3.2 Alert Priorities
- **INFO:** Telegram (Silent). E.g., "Regime changed to Trend".
- **TRADE:** Telegram + Push. E.g., "Opened Buy 0.1 lots".
- **CRITICAL:** Telegram (Loud) + Push + Sound. E.g., "Margin Low", "Disconnect".

## 4. Remote Control Logic
- **Polling:** Every 2-5 seconds, check Telegram `getUpdates`.
- **Command Map:**
    - `/status` -> Returns Account Equity, Open Trades, Current Regime.
    - `/close_all` -> Triggers `CProfitManager::CloseAll()`.
    - `/pause` -> Sets `m_trading_enabled = false`.
- **Security:** Whitelist `ChatID` to prevent unauthorized access.

## 5. Implementation Roadmap
1.  **`TelegramBot.mqh`**: Wrapper for API calls.
2.  **`PushService.mqh`**: Wrapper for `SendNotification`.
3.  **`CommunicationManager.mqh`**: Aggregator.
4.  **Integration**: Connect to `Assistant_Showcase` timer loop.
