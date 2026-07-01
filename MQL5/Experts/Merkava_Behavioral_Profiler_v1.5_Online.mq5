//+------------------------------------------------------------------+
//|                             Merkava_Behavioral_Profiler_v1.5_Online.mq5 |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 1.5 (Added DOM MarketBookGet + Socket payload support)    |
//|        (Integration: Context v3.28 4 EMAs, Native EMA removed)   |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "1.50"
#property strict

#include "../Indicators/Types_v2_16.mqh"
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <AccountInfo.mqh>

#include "../Indicators/FireControl_v2_25.mqh"
#include "../Indicators/PanelControl_v2_23.mqh"
#include "../Indicators/PhysicsEngine.mqh"
#include "../Indicators/NavSystem_v2_22.mqh"
#include "../Indicators/BlackBox_v2_10.mqh"
#include "../Indicators/ProfitManagement_v2_19.mqh"

CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
CAccountInfo  m_account;

PhysicsEngine m_physics(50);
CFireControl  m_fire_control;
CPanelControl m_panel;
CNavSystem    m_nav_system;
CBlackBox     m_black_box;
CProfitManager m_profit_manager;

//--- Inputs
input double        InpSpreadMultStart   = 1.5;
input double        InpSpreadMultStep    = 1.0;
input int           InpLayers            = 1;
input double        InpMinSpreadPoints   = 60.0;
input double        InpSafeZonePts       = 50.0;
input string        InpIndPath           = "Jules\\";

input double        InpLotSize           = 0.01;
input int           InpSlippage          = 10;
input ulong         InpMagicNumber       = 999030; // Fallback only (if Stealth OFF)
input double        InpVirtualTPCurrency = 0.0;
input double        InpVirtualSLCurrency = 0.0;
input double        InpMaxMarginPercent  = 70.0;
input string        InpComment           = ""; // DEFAULT EMPTY (Total Silence)

// [Hybrid & Flow Settings]
input int           Hybrid_FastEMA       = 3;
input int           Hybrid_SlowEMA       = 6;
input double        Hybrid_MACDScale     = 4.0;
input double        Hybrid_DFScale       = 1.0;
input bool          Hybrid_AutoScaling   = true;
input double        Hybrid_Divisor       = 7.0;

input int           Flow_MFIPeriod       = 5;
input int           Flow_VROCPeriod      = 5;
input int           Flow_Smooth          = 3;
input int           Flow_NormLen         = 100;
input double        Flow_Scale           = 50.0;

// [Hybrid Context Settings v3.28]
input string        InpContextPath       = "Jules\\HybridContextIndicator_v3.28";

input bool          Ctx_ShowPivots       = true;
input bool          Ctx_ShowTrends       = true;
input int           Ctx_MaxHistory       = 50000;

input bool          Ctx_ShowFibo         = false; // Forced OFF usually
input int           Ctx_FiboHist         = 0;

input bool          Ctx_Mic_Use          = true;
input int           Ctx_Mic_Depth        = 3;
input int           Ctx_Mic_Dev          = 5;
input int           Ctx_Mic_Back         = 3;
input ENUM_LINE_STYLE Ctx_Mic_Style      = STYLE_DOT; // DOTS
input int           Ctx_Mic_Width        = 1;
input color         Ctx_Mic_ColorR       = clrRed;
input color         Ctx_Mic_ColorS       = clrGreen;

input bool          Ctx_Sec_Use          = true;
input int           Ctx_Sec_Depth        = 4;
input int           Ctx_Sec_Dev          = 5;
input int           Ctx_Sec_Back         = 3;
input ENUM_LINE_STYLE Ctx_Sec_Style      = STYLE_DASHDOT;
input int           Ctx_Sec_Width        = 1;
input color         Ctx_Sec_ColorR       = clrRed;
input color         Ctx_Sec_ColorS       = clrGreen;

input bool          Ctx_Ter_Use          = true;
input int           Ctx_Ter_Depth        = 7;
input int           Ctx_Ter_Dev          = 5;
input int           Ctx_Ter_Back         = 3;
input ENUM_LINE_STYLE Ctx_Ter_Style      = STYLE_SOLID;
input int           Ctx_Ter_Width        = 1;
input color         Ctx_Ter_ColorR       = clrRed;
input color         Ctx_Ter_ColorS       = clrGreen;

input int           Ctx_Tr_FastP         = 25;
input int           Ctx_Tr_MedP          = 50;
input int           Ctx_Tr_SlowP         = 150;
input int           Ctx_Tr_SuperP        = 300;
input ENUM_MA_METHOD Ctx_Tr_Method       = MODE_EMA;


// [Panel UI]
input int           InpX                 = 10;
input int           InpY                 = 20;


//--- Online Python Bridge Settings ---
input group "=== Python Bridge Settings ==="
input bool   InpEnablePythonBridge = true;       // Enable TCP Bridge to Python HMM Engine
input string InpBridgeHost         = "127.0.0.1"; // Python Server IP
input int    InpBridgePort         = 5555;       // Python Server Port (Vaku Dashboard)
input int    InpDomBridgePort      = 5556;       // Python DOM HUD Port
input int    InpHistoryTicks       = 10000;        // Number of Ticks to send on Init

//--- Socket Variables
int          g_socket = INVALID_HANDLE;       // Vaku 3.0 Socket
int          g_dom_socket = INVALID_HANDLE;   // DOM HUD Socket
bool         g_socket_connected = false;
bool         g_dom_socket_connected = false;
datetime     g_last_reconnect_time = 0;


input color         InpBgColor           = clrDarkSlateGray;
input color         InpTxtColor          = clrWhite;

// Globals
bool g_active = false;
bool g_book_subscribed = false;
string g_last_action = "IDLE";
double g_last_realized_pl = 0.0;
double g_session_realized_pl = 0.0;
string g_tick_event_buffer = "";
string g_decision_log = "";
string g_transaction_buffer = "";
ulong g_last_deal_ticket = 0;
long g_last_deal_time_msc = 0;
int g_debug_counter = 0;
string Prefix = "MerkavaV2_";

// Helper Functions
double GetFloatingPL() {
    double pl = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i)) {
           if(m_position.Magic() == InpMagicNumber)
               pl += m_position.Profit() + m_position.Swap() + m_position.Commission();
       }
    }
    return pl;
}

double CalculateTotalHistoryProfit() {
    double total_profit = 0.0;
    if (HistorySelect(0, TimeCurrent())) {
        int total = HistoryDealsTotal();
        for(int i=0; i<total; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            if (type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) {
                // Note: History checking for Deep Stealth is harder as closed tickets are removed from registry.
                // For now, we calculate TOTAL profit of account to avoid complexity, or only filter by Magic if NOT Deep Stealth.
                // Assuming Account Profit for now as Deep Stealth hides ownership.
                total_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
                total_profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
                total_profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
        }
    }
    return total_profit;
}


//+------------------------------------------------------------------+
//| Socket Bridge Functions                                          |
//+------------------------------------------------------------------+
bool ConnectToPython() {
    if(!InpEnablePythonBridge) return false;

    // 1. Connect Vaku 3.0 Dashboard (Port 5555)
    if(g_socket != INVALID_HANDLE) SocketClose(g_socket);
    g_socket = SocketCreate();
    if(g_socket != INVALID_HANDLE) {
        if(SocketConnect(g_socket, InpBridgeHost, InpBridgePort, 5000)) {
            g_socket_connected = true;
            Print("✅ Successfully connected to Vaku 3.0 Dashboard on ", InpBridgeHost, ":", InpBridgePort);
        } else {
            Print("❌ Failed to connect to Vaku 3.0 Dashboard. Error: ", GetLastError());
            SocketClose(g_socket);
            g_socket = INVALID_HANDLE;
            g_socket_connected = false;
        }
    }

    // 2. Connect DOM HUD (Port 5556)
    if(g_dom_socket != INVALID_HANDLE) SocketClose(g_dom_socket);
    g_dom_socket = SocketCreate();
    if(g_dom_socket != INVALID_HANDLE) {
        if(SocketConnect(g_dom_socket, InpBridgeHost, InpDomBridgePort, 5000)) {
            g_dom_socket_connected = true;
            Print("✅ Successfully connected to DOM HUD on ", InpBridgeHost, ":", InpDomBridgePort);
        } else {
            Print("❌ Failed to connect to DOM HUD. Error: ", GetLastError());
            SocketClose(g_dom_socket);
            g_dom_socket = INVALID_HANDLE;
            g_dom_socket_connected = false;
        }
    }

    return (g_socket_connected || g_dom_socket_connected);
}

void SendHistoryToPython() {
    if(!g_socket_connected) return;

    MqlTick ticks[];
    int copied = CopyTicks(_Symbol, ticks, COPY_TICKS_ALL, 0, InpHistoryTicks);

    if(copied > 0) {
        // Kezdő üzenet
        string start_msg = "HISTORY_START|" + IntegerToString(copied) + "\n";
        uchar s_buf[];
        StringToCharArray(start_msg, s_buf);
        SocketSend(g_socket, s_buf, ArraySize(s_buf) - 1);

        // Csomagokban küldjük, hogy elkerüljük az MQL5 string fagyást (O(N^2) concatenation lag)
        int chunk_size = 500;
        string chunk_payload = "";

        for(int i=0; i<copied; i++) {
            chunk_payload += IntegerToString(ticks[i].time_msc) + "|" + DoubleToString(ticks[i].bid, _Digits) + "|" + DoubleToString(ticks[i].ask, _Digits) + "\n";

            if(i % chunk_size == 0 || i == copied - 1) {
                uchar buffer[];
                StringToCharArray(chunk_payload, buffer);
                if(SocketSend(g_socket, buffer, ArraySize(buffer) - 1) < 0) {
                    Print("❌ Failed to send History Chunk. Error: ", GetLastError());
                    g_socket_connected = false;
                    return;
                }
                chunk_payload = ""; // Reset
            }
        }

        // Záró üzenet
        string end_msg = "HISTORY_END\n";
        uchar e_buf[];
        StringToCharArray(end_msg, e_buf);
        SocketSend(g_socket, e_buf, ArraySize(e_buf) - 1);

        Print("📤 History Sent (", copied, " ticks) to Python in chunks.");
    }
}

void SendTickToPython(long time_msc, double bid, double ask, int pos_type, double pos_price, double pos_profit, long av1, long av2, long bv1, long bv2, double ap1, double ap2, double bp1, double bp2) {
    if(!g_socket_connected && !g_dom_socket_connected) return;

    // Alap Vaku payload (rövidebb, hogy kompatibilis maradjon a Vaku3 kóddal)
    string payload_vaku = "TICK|" + IntegerToString(time_msc) + "|" + DoubleToString(bid, _Digits) + "|" + DoubleToString(ask, _Digits) + "|" + IntegerToString(pos_type) + "|" + DoubleToString(pos_price, _Digits) + "|" + DoubleToString(pos_profit, 2) + "\n";

    // Teljes DOM payload a DOM HUD számára
    string payload_dom = "TICK|" + IntegerToString(time_msc) + "|" + DoubleToString(bid, _Digits) + "|" + DoubleToString(ask, _Digits) + "|" + IntegerToString(pos_type) + "|" + DoubleToString(pos_price, _Digits) + "|" + DoubleToString(pos_profit, 2) + "|" + IntegerToString(av1) + "|" + IntegerToString(av2) + "|" + IntegerToString(bv1) + "|" + IntegerToString(bv2) + "|" + DoubleToString(ap1, _Digits) + "|" + DoubleToString(ap2, _Digits) + "|" + DoubleToString(bp1, _Digits) + "|" + DoubleToString(bp2, _Digits) + "\n";

    if(g_socket_connected) {
        uchar buffer_vaku[];
        StringToCharArray(payload_vaku, buffer_vaku);
        if(SocketSend(g_socket, buffer_vaku, ArraySize(buffer_vaku) - 1) < 0) {
            g_socket_connected = false;
        }
    }

    if(g_dom_socket_connected) {
        uchar buffer_dom[];
        StringToCharArray(payload_dom, buffer_dom);
        if(SocketSend(g_dom_socket, buffer_dom, ArraySize(buffer_dom) - 1) < 0) {
            g_dom_socket_connected = false;
        }
    }
}

int OnInit()
{
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
   m_nav_system.Release();
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);

   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
       Print("⚠️ WARNING: Account is NOT in Hedging Mode! Instant Entry (Hedge) may fail.");
   }

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();
   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;

   // --- INITIALIZE STEALTH ENGINE ---
   m_fire_control.Init(&m_trade, &m_symbol, InpComment, InpMagicNumber, NULL, NULL);
   m_profit_manager.Init(&m_trade, &m_position, InpMagicNumber, _Symbol, NULL);

   // --- Python Bridge Init ---
   if(InpEnablePythonBridge) {
       if(ConnectToPython()) {
           SendHistoryToPython();
       }
   }


   m_profit_manager.SetSlippage((ulong)InpSlippage);
   m_profit_manager.SetVirtualTP(InpVirtualTPCurrency);
   m_profit_manager.SetVirtualSL(InpVirtualSLCurrency);

   if(InpVirtualTPCurrency > 0) PrintFormat("💰 Profit Manager Active: Virtual TP = %.2f %s", InpVirtualTPCurrency, AccountInfoString(ACCOUNT_CURRENCY));
   if(InpVirtualSLCurrency > 0) PrintFormat("🛑 Profit Manager Active: Virtual SL = %.2f %s", InpVirtualSLCurrency, AccountInfoString(ACCOUNT_CURRENCY));

   // Prepare Context Params (v3.28)
   ContextParams ctx;
   ctx.path = InpContextPath;
   ctx.show_pivots = Ctx_ShowPivots; ctx.show_trends = Ctx_ShowTrends; ctx.max_hist = Ctx_MaxHistory;
   ctx.show_fibo = Ctx_ShowFibo; ctx.fibo_hist = Ctx_FiboHist;
   // Micro
   ctx.m_use = Ctx_Mic_Use; ctx.m_depth = Ctx_Mic_Depth; ctx.m_dev = Ctx_Mic_Dev; ctx.m_back = Ctx_Mic_Back;
   ctx.m_style = Ctx_Mic_Style; ctx.m_width = Ctx_Mic_Width; ctx.m_c1 = Ctx_Mic_ColorR; ctx.m_c2 = Ctx_Mic_ColorS;
   // Sec
   ctx.s_use = Ctx_Sec_Use; ctx.s_depth = Ctx_Sec_Depth; ctx.s_dev = Ctx_Sec_Dev; ctx.s_back = Ctx_Sec_Back;
   ctx.s_style = Ctx_Sec_Style; ctx.s_width = Ctx_Sec_Width; ctx.s_c1 = Ctx_Sec_ColorR; ctx.s_c2 = Ctx_Sec_ColorS;
   // Ter
   ctx.t_use = Ctx_Ter_Use; ctx.t_depth = Ctx_Ter_Depth; ctx.t_dev = Ctx_Ter_Dev; ctx.t_back = Ctx_Ter_Back;
   ctx.t_style = Ctx_Ter_Style; ctx.t_width = Ctx_Ter_Width; ctx.t_c1 = Ctx_Ter_ColorR; ctx.t_c2 = Ctx_Ter_ColorS;
   // Trends
   ctx.tr_fast = Ctx_Tr_FastP; ctx.tr_medium = Ctx_Tr_MedP; ctx.tr_slow = Ctx_Tr_SlowP; ctx.tr_super = Ctx_Tr_SuperP; ctx.tr_method = Ctx_Tr_Method;

   // Prepare Dummy Momentum Params (since it's removed but struct might still be required by NavSystem signature)
   HybridMomentumParams mom;
   ZeroMemory(mom);
   mom.path = InpIndPath + "Hybrid_Momentum_WPR_Stoch_v1_04";
   mom.wpr_period = 5;
   mom.stoch_k = 3;
   mom.stoch_slow = 2;
   mom.stoch_d = 2;

   bool init_ok = m_nav_system.Initialize(
       _Symbol, _Period,
       InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.05",
       Hybrid_FastEMA, Hybrid_SlowEMA, 20, 2.0, MODE_EMA,
       20, 1.5, 10, MODE_EMA,
       Hybrid_MACDScale, 0, Hybrid_DFScale, Hybrid_AutoScaling, 100,
       Hybrid_Divisor,
       InpIndPath + "HybridFlowIndicator_v1.126",
       false, -100, 200, Flow_MFIPeriod, true, Flow_VROCPeriod, true,
       Flow_Smooth, Flow_NormLen, Flow_Scale, 3.0,
       ctx, mom
   );

   if(init_ok) {
       m_nav_system.AttachToChart(0); // Attaches Context to Main (0) and others to Sub (1,2,3)
   }

   m_black_box.Initialize(_Symbol, "v1.10");

   // --- DYNAMIC VERSION LABEL (Fixed) ---
   string version_str = "MERKAVA PROFILER v1.1";

   m_panel.Init(Prefix, InpX, InpY, InpBgColor, InpTxtColor,
                InpLotSize, InpSpreadMultStart, InpSpreadMultStep, InpLayers, InpMinSpreadPoints,
                InpVirtualTPCurrency, InpVirtualSLCurrency, version_str); // Passed version here
   m_panel.Create();
   m_panel.UpdateUI(GetFloatingPL());

   Print("Merkava PROFILER v1.1 Initialized (Strict Silence).");
   if(InpEnablePythonBridge) { MarketBookAdd(_Symbol); }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(InpEnablePythonBridge) { MarketBookRelease(_Symbol); }
   m_panel.Destroy();
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
   m_nav_system.Release();
   m_black_box.CloseLog();
   if(g_book_subscribed) MarketBookRelease(_Symbol);
}

//+------------------------------------------------------------------+
//| Chart Event - FULL RESTORATION                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Delegate to Panel Control
   ENUM_PANEL_EVENT event = m_panel.OnEvent(id, lparam, dparam, sparam);

   if (event != EVENT_NONE)
   {
       double center = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;

       // Retrieve Params from Panel
       double lot = m_panel.GetLotSize();
       int layers = m_panel.GetLayers();
       double mstart = m_panel.GetMultStart();
       double mstep = m_panel.GetMultStep();
       double mindist = m_panel.GetMinDist();
       ENUM_FIRE_MODE mode = m_panel.GetFireMode();
       ENUM_ENTRY_MODE entry = m_panel.GetEntryMode();

       // --- SAFETY MARGIN CHECK ---
       double equity = AccountInfoDouble(ACCOUNT_EQUITY);
       double margin = AccountInfoDouble(ACCOUNT_MARGIN);
       double margin_percent = (equity > 0) ? (margin / equity) * 100.0 : 0.0;

       // Only block FIRE events (Buy, Sell, Both)
       if (margin_percent > InpMaxMarginPercent && (event == EVENT_FIRE || event == EVENT_FIRE_BUY || event == EVENT_FIRE_SELL)) {
           PrintFormat("⛔ SAFETY MARGIN LIMIT HIT! Used: %.1f%% > Limit: %.1f%%. Fire BLOCKED.", margin_percent, InpMaxMarginPercent);
           Alert("⛔ SAFETY MARGIN LIMIT HIT! Used: %.1f%% > Limit: %.1f%%. Fire BLOCKED.");
           return; // BLOCK EXECUTION
       }
       // --------------------------

       // Handle Events
       if (event == EVENT_FIRE)
       {
           // TRAP (BOTH)
           m_fire_control.FireGrid(center, lot, layers, mstart, mstep, mindist, mode, entry, ATTACK_BOTH);

           g_last_action = (mode == FIRE_MODE_STOP) ? "TRAP_SET" : "LIMIT_GRID";
           if (entry == ENTRY_MARKET) g_last_action += "_INSTANT";
           g_decision_log += "Grid Fired BOTH L" + IntegerToString(layers) + ";";
       }
       else if (event == EVENT_FIRE_BUY)
       {
           // BUY ONLY
           m_fire_control.FireGrid(center, lot, layers, mstart, mstep, mindist, mode, entry, ATTACK_BUY);

           g_last_action = "FIRE_BUY";
           if (entry == ENTRY_MARKET) g_last_action += "_INSTANT";
           g_decision_log += "Grid Fired BUY L" + IntegerToString(layers) + ";";
       }
       else if (event == EVENT_FIRE_SELL)
       {
           // SELL ONLY
           m_fire_control.FireGrid(center, lot, layers, mstart, mstep, mindist, mode, entry, ATTACK_SELL);

           g_last_action = "FIRE_SELL";
           if (entry == ENTRY_MARKET) g_last_action += "_INSTANT";
           g_decision_log += "Grid Fired SELL L" + IntegerToString(layers) + ";";
       }
       else if (event == EVENT_CEASE_FIRE)
       {
           m_fire_control.CeaseFire();
           g_last_action = "CEASE_FIRE";
           g_decision_log += "Cease Fire;";
       }
       else if (event == EVENT_CLOSE_PROFIT) // Close All Profit
       {
           int closed = m_profit_manager.CloseAllProfit();
           g_last_action = "CLOSE_PROFIT";
           g_decision_log += "Manually Closed " + IntegerToString(closed) + " Profitable Positions;";
       }
       else if (event == EVENT_TP_SL_UPDATE) // Sync Virtual TP/SL
       {
           double vtp = m_panel.GetVirtualTP();
           double vsl = m_panel.GetVirtualSL();
           m_profit_manager.SetVirtualTP(vtp);
           m_profit_manager.SetVirtualSL(vsl);
           PrintFormat("🔄 Sync: Virtual TP=%.2f, Virtual SL=%.2f", vtp, vsl);
       }
       else if (event == EVENT_PARAM_UPDATE)
       {
           PrintFormat("Merkava Params Updated: Lot=%.2f, MultStart=%.1f, MultStep=%.1f, Layers=%d",
                      m_panel.GetLotSize(), m_panel.GetMultStart(), m_panel.GetMultStep(), m_panel.GetLayers());
       }
       else if (event == EVENT_CHANGE_MODE)
       {
           Print("🔄 Mode Changed: " + EnumToString(mode));
       }
       else if (event == EVENT_CHANGE_ENTRY)
       {
           Print("⚡ Entry Changed: " + EnumToString(entry));
       }
       else if (event == EVENT_TOGGLE_VISUAL)
       {
           // visual_active state is tracked inside the panel itself or nav system
           // Since the user just clicked it, let's sync state
           // m_panel keeps its own state in `m_visual_active`, let's just use it
           // Alternatively we can just read from panel? No explicit getter yet, so we just toggle in Nav.
           bool current_vis = m_panel.GetVisualActive(); // Need to add getter
           m_nav_system.ToggleVisual(0, current_vis);
           Print("👁️ Visual Mode Toggled: " + (current_vis ? "ON" : "OFF"));
       }
   }

   // Always Update UI
   m_panel.UpdateUI(GetFloatingPL());
}

// --- Restored Helper Functions ---

string GetNetLotDirection(double &total_lots) {
    double net = 0.0; total_lots = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i)) {
           if(m_position.Magic() == InpMagicNumber) {
               total_lots += m_position.Volume();
               if(m_position.PositionType()==POSITION_TYPE_BUY) net+=m_position.Volume(); else net-=m_position.Volume();
           }
       }
    }
    if(net > 0.001) return "BUY";
    if(net < -0.001) return "SELL";
    if(PositionsTotal() > 0) return "NEUTRAL";
    return "NONE";
}

string DetermineVerdict(double v, double pl) {
    if(pl < -50.0 && v > 20.0) return "CRASH_RISK";
    if(pl > 10.0) return "WINNING";
    if(pl < -10.0) return "PRESSURE";
    return "STABLE";
}

string GetSLTPSnapshot() {
    string s = ""; int c = 0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i)) {
           if(m_position.Magic() == InpMagicNumber) {
               if(c > 0) s += "|";
               string t = (m_position.PositionType()==POSITION_TYPE_BUY) ? "B" : "S";
               s += t + ":" + DoubleToString(m_position.StopLoss(),_Digits) + "/" + DoubleToString(m_position.TakeProfit(),_Digits);
               c++; if(c>=3) { s+="|..."; break; }
           }
       }
    }
    return (s=="") ? "NONE" : s;
}

void CheckForNewDeals()
{
    if(!HistorySelect(TimeCurrent() - 600, TimeCurrent() + 10)) return;
    int total = HistoryDealsTotal();

    for(int i=0; i<total; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        long deal_time = HistoryDealGetInteger(ticket, DEAL_TIME_MSC);

        if (deal_time > g_last_deal_time_msc || (deal_time == g_last_deal_time_msc && ticket > g_last_deal_ticket)) {
            g_last_deal_time_msc = deal_time;
            g_last_deal_ticket = ticket;

            long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            double vol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

            string type_str = (type == DEAL_TYPE_BUY) ? "BUY" : "SELL";
            string info = "T#" + IntegerToString(ticket);

            if (entry == DEAL_ENTRY_IN) {
                if(g_transaction_buffer!="") g_transaction_buffer+="|";
                g_transaction_buffer += info + ":OPEN:" + type_str + ":" + DoubleToString(vol,2);
            } else if (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
                if(g_transaction_buffer!="") g_transaction_buffer+="|";
                g_transaction_buffer += info + ":CLOSE:" + type_str + ":PL=" + DoubleToString(profit,2);
                g_last_realized_pl += profit;
                g_session_realized_pl += profit;
            }
        }
    }
}

void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   m_physics.Update(tick);
   PhysicsState p = m_physics.GetState();
   m_nav_system.Refresh(_Symbol, tick);

   g_debug_counter++;

   CheckForNewDeals();

   // --- Python Bridge Tick Update & Auto-Reconnect ---
   if(InpEnablePythonBridge) {
       if((!g_socket_connected || !g_dom_socket_connected) && (TimeCurrent() - g_last_reconnect_time > 5)) {
           g_last_reconnect_time = TimeCurrent();
           if(ConnectToPython()) {
               // Optional: Re-send history on reconnect if needed, but for now just resume ticks
           }
       }
       if(g_socket_connected || g_dom_socket_connected) {
           int pos_type = 0;
           double pos_price = 0.0;
           double pos_profit = 0.0;
           if(PositionsTotal() > 0) {
               // Megkeressük a legelső nyitott pozíciót a charton (ami ehhez az EA-hez/Symbol-hoz tartozik)
               for(int i=0; i<PositionsTotal(); i++) {
                   if(m_position.SelectByIndex(i)) {
                       if(m_position.Symbol() == _Symbol) {
                           pos_price = m_position.PriceOpen();
                           pos_type = (m_position.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
                           pos_profit = m_position.Profit();
                           break;
                       }
                   }
               }
           }

           // Fetch DOM Data
           long av1 = 0, av2 = 0, bv1 = 0, bv2 = 0;
           double ap1 = 0.0, ap2 = 0.0, bp1 = 0.0, bp2 = 0.0;
           MqlBookInfo book[];
           if (MarketBookGet(_Symbol, book)) {
               int size = ArraySize(book);
               int buy_start_idx = -1;
               for(int i=0; i<size; i++) {
                   if(book[i].type == BOOK_TYPE_BUY) {
                       buy_start_idx = i;
                       break;
                   }
               }

               if(buy_start_idx > 0) {
                   if(buy_start_idx - 1 >= 0) { ap1 = book[buy_start_idx - 1].price; av1 = book[buy_start_idx - 1].volume; }
                   if(buy_start_idx - 2 >= 0) { ap2 = book[buy_start_idx - 2].price; av2 = book[buy_start_idx - 2].volume; }
               } else if (buy_start_idx == -1 && size >= 2) {
                   ap1 = book[size - 1].price; av1 = book[size - 1].volume;
                   ap2 = book[size - 2].price; av2 = book[size - 2].volume;
               }

               if(buy_start_idx != -1) {
                   if(buy_start_idx < size) { bp1 = book[buy_start_idx].price; bv1 = book[buy_start_idx].volume; }
                   if(buy_start_idx + 1 < size) { bp2 = book[buy_start_idx + 1].price; bv2 = book[buy_start_idx + 1].volume; }
               }
           }

           SendTickToPython(tick.time_msc, tick.bid, tick.ask, pos_type, pos_price, pos_profit, av1, av2, bv1, bv2, ap1, ap2, bp1, bp2);
       }
   }


   int closed = m_profit_manager.Check();
   if(closed > 0) {
       g_last_action = "VIRTUAL_TP_SL_HIT";
       g_decision_log += "Closed " + IntegerToString(closed) + " positions via Virtual Manager;";
   }

   double float_pl = GetFloatingPL();
   m_panel.UpdateUI(float_pl);
   m_panel.UpdateAccountStats(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY), AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_FREE), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), CalculateTotalHistoryProfit(), g_session_realized_pl);

   MqlBookInfo book[];
   long bid_vol = 0;
   long ask_vol = 0;
   if (g_book_subscribed && MarketBookGet(_Symbol, book)) {
       int size = ArraySize(book);
       for(int i=0; i<size; i++) {
           if((book[i].type == BOOK_TYPE_SELL) && (book[i].price == m_symbol.Ask())) ask_vol += book[i].volume;
           if((book[i].type == BOOK_TYPE_BUY) && (book[i].price == m_symbol.Bid())) bid_vol += book[i].volume;
       }
   } else {
       // Fallback to basic tick volume if DOM is not available
       bid_vol = (long)tick.volume;
       ask_vol = (long)tick.volume;
   }

   MqlRates rates[];
   double b_o=0, b_h=0, b_l=0, b_c=0;
   if(CopyRates(_Symbol, PERIOD_M1, 0, 1, rates) > 0) {
       b_o = rates[0].open; b_h = rates[0].high; b_l = rates[0].low; b_c = rates[0].close;
   }

   double total_lots = 0; // Fixed Declaration
   string lot_dir = GetNetLotDirection(total_lots);
   string verdict = DetermineVerdict(p.velocity, float_pl);

   if (g_transaction_buffer == "") g_transaction_buffer = "NONE";
   if (g_decision_log != "") g_transaction_buffer += "|" + g_decision_log;

   m_black_box.RecordTick(
       tick.time_msc, g_last_action, 0, verdict,
       tick.bid, tick.ask, p.spread_avg, bid_vol, ask_vol,
       b_o, b_h, b_l, b_c,
       m_nav_system.GetRSI(), p.velocity, p.acceleration,
       m_nav_system.GetHybridMACD(), m_nav_system.GetPulse(),
       m_nav_system.GetFlowMFI(), m_nav_system.GetFlowROC(), m_nav_system.GetFlowDelta(),
       // Context
       m_nav_system.GetMicP(), m_nav_system.GetMicR(), m_nav_system.GetMicS(),
       m_nav_system.GetSecP(), m_nav_system.GetSecR(), m_nav_system.GetSecS(),
       m_nav_system.GetTerP(), m_nav_system.GetTerR(), m_nav_system.GetTerS(),
       // Context EMAs
       m_nav_system.GetTrendFast(), m_nav_system.GetTrendMedium(), m_nav_system.GetTrendSlow(), m_nav_system.GetTrendSuper(),
       m_nav_system.GetWPR(), m_nav_system.GetStochK(),
       TerminalInfoInteger(TERMINAL_PING_LAST), // Ping for Anomaly Detection
       // Stats
       AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),
       float_pl, g_last_realized_pl, g_session_realized_pl,
       PositionsTotal(), lot_dir, total_lots,
       GetSLTPSnapshot(), g_transaction_buffer, g_tick_event_buffer
   );

   g_last_realized_pl = 0.0;
   g_tick_event_buffer = "";
   g_decision_log = "";
   g_transaction_buffer = "";
   if (g_last_action != "IDLE") g_last_action = "IDLE";
}
