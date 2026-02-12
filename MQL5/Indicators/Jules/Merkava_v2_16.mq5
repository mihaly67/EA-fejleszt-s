//+------------------------------------------------------------------+
//|                                                Merkava_v2_16.mq5 |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 2.16   |
//|                    (Context Indicator Integration + CSV Expansion) |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "2.16"
#property strict

#include "../Indicators/Types_v2_16.mqh" // Types first
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <AccountInfo.mqh>

// Library Organization (v2.16)
#include "../Indicators/FireControl_v2_16.mqh"
#include "../Indicators/PanelControl_v2_16.mqh"
#include "../Indicators/PhysicsEngine.mqh"
#include "../Indicators/NavSystem_v2_08.mqh"
#include "../Indicators/BlackBox_v2_06.mqh"
#include "../Indicators/ProfitManagement_v2_16.mqh" // Added ProfitManager

//--- Objects
CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
CAccountInfo  m_account;

PhysicsEngine m_physics(50);
CFireControl  m_fire_control;
CPanelControl m_panel;
CNavSystem    m_nav_system;
CBlackBox     m_black_box;
CProfitManager m_profit_manager; // Added Instance

//--- Inputs
// [Strategy Settings - Defaults]
input double        InpSpreadMultStart   = 1.5;
input double        InpSpreadMultStep    = 1.0;
input int           InpLayers            = 3;
input double        InpMinSpreadPoints   = 60.0; // Adaptive Minimum Spread
input double        InpSafeZonePts       = 50.0;
input string        InpIndPath           = "Jules\\";

// [Position Size]
input double        InpLotSize           = 0.01;

// [Risk Management]
input int           InpSlippage          = 10;
input ulong         InpMagicNumber       = 999015; // Updated Magic v2.15
input double        InpVirtualTPCurrency = 0.0;    // Added: Invisible TP (0.0 = Off)
input double        InpVirtualSLCurrency = 0.0;    // Added: Invisible SL (0.0 = Off)
input double        InpMaxMarginPercent  = 70.0;   // Added: Safety Margin (Stop Entry)
input string        InpComment           = "Merkava_v2.16";

// [Hybrid & Flow Settings]
input int           Hybrid_FastEMA       = 3;
input int           Hybrid_SlowEMA       = 6;
input double        Hybrid_MACDScale     = 4.0;
input double        Hybrid_DFScale       = 1.0;
input bool          Hybrid_AutoScaling   = true;
input double        Hybrid_Divisor       = 7.0; // v2.06: Precision Divider

input int           Flow_MFIPeriod       = 5;
input int           Flow_VROCPeriod      = 5;
input int           Flow_Smooth          = 3;
input int           Flow_NormLen         = 100;
input double        Flow_Scale           = 50.0;

// [Context Indicator Settings]
input group         "=== Context Indicator Settings ==="
input string        InpContextPath       = "Jules\\HybridContextIndicator_v3.17";
input bool          InpShowPivots        = true;
input bool          InpShowTrends        = true;
input int           InpMaxHistoryBars    = 50000;
input bool          InpShowFibo          = false; // CSV Excluded
input int           InpFiboMicroHistory  = 0;

input bool          InpUseMicro          = true;
input int           InpMicroDepth        = 3;
input int           InpMicroDeviation    = 5;
input int           InpMicroBackstep     = 3;
input ENUM_LINE_STYLE InpMicroStyle      = STYLE_DOT;
input int           InpMicroWidth        = 1;
input color         InpMicroColorR1      = clrRed;
input color         InpMicroColorS1      = clrGreen;

input bool          InpUseSecondary      = true;
input int           InpSecDepth          = 10;
input int           InpSecDeviation      = 10;
input int           InpSecBackstep       = 5;
input ENUM_LINE_STYLE InpSecStyle        = STYLE_DASHDOT;
input int           InpSecWidth          = 1;
input color         InpSecColorR1        = clrRed;
input color         InpSecColorS1        = clrGreen;

input bool          InpUseTertiary       = true;
input int           InpTerDepth          = 20;
input int           InpTerDeviation      = 10;
input int           InpTerBackstep       = 5;
input ENUM_LINE_STYLE InpTerStyle        = STYLE_SOLID;
input int           InpTerWidth          = 1;
input color         InpTerColorR1        = clrRed;
input color         InpTerColorS1        = clrGreen;

input int           InpTrendFastPeriod   = 50;
input int           InpTrendSlowPeriod   = 150;
input ENUM_MA_METHOD InpTrendMethod      = MODE_EMA;

// [Panel UI]
input int           InpX                 = 10;
input int           InpY                 = 20;
input color         InpBgColor           = clrDarkSlateGray;
input color         InpTxtColor          = clrWhite;

//--- Globals (Dynamic Parameters)
bool              g_active = false;
bool              g_book_subscribed = false;

string            g_last_action = "IDLE";
double            g_last_realized_pl = 0.0;
double            g_session_realized_pl = 0.0;
string            g_tick_event_buffer = "";
string            g_decision_log = "";
string            g_transaction_buffer = "";

ulong             g_last_deal_ticket = 0;
long              g_last_deal_time_msc = 0;

string Prefix = "MerkavaV2_";

//====================================================================
// HELPER FUNCTIONS
//====================================================================

double GetFloatingPL() {
    double pl = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Magic()==InpMagicNumber)
           pl += m_position.Profit() + m_position.Swap() + m_position.Commission();
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
            // Filter only TRADE deals (exclude Balance/Credit)
            if (type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) {
                total_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
                total_profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
                total_profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
        }
    }
    return total_profit;
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();

   m_nav_system.Release();
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);

   // Verify Hedging Mode
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
       Print("⚠️ WARNING: Account is NOT in Hedging Mode! Instant Entry (Hedge) may fail or close positions.");
   }

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;

   // v2.15: Initialize FireControl with pointers
   m_fire_control.Init(&m_trade, &m_symbol, InpComment, InpMagicNumber);

   // v2.15: Initialize ProfitManager
   m_profit_manager.Init(&m_trade, &m_position, InpMagicNumber, _Symbol);
   m_profit_manager.SetVirtualTP(InpVirtualTPCurrency);
   m_profit_manager.SetVirtualSL(InpVirtualSLCurrency);

   if(InpVirtualTPCurrency > 0) PrintFormat("💰 Profit Manager Active: Virtual TP = %.2f %s", InpVirtualTPCurrency, AccountInfoString(ACCOUNT_CURRENCY));
   if(InpVirtualSLCurrency > 0) PrintFormat("🛑 Profit Manager Active: Virtual SL = %.2f %s", InpVirtualSLCurrency, AccountInfoString(ACCOUNT_CURRENCY));
   if(InpMaxMarginPercent > 0) PrintFormat("🛡️ Safety Margin Active: Limit = %.1f%%", InpMaxMarginPercent);

   bool init_ok = m_nav_system.Initialize(
       _Symbol, _Period,
       InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.05", // v2.06: Point to v1.05
       Hybrid_FastEMA, Hybrid_SlowEMA, 20, 2.0, MODE_EMA,
       20, 1.5, 10, MODE_EMA,
       Hybrid_MACDScale, 0, Hybrid_DFScale, Hybrid_AutoScaling, 100,
       Hybrid_Divisor, // v2.06: Pass Divisor
       InpIndPath + "HybridFlowIndicator_v1.125",
       false, -100, 200, Flow_MFIPeriod, true, Flow_VROCPeriod, 20.0, true,
       Flow_Smooth, Flow_NormLen, Flow_Scale, 3.0,
       // Context
       InpContextPath,
       InpShowPivots, InpShowTrends, InpMaxHistoryBars, InpShowFibo, InpFiboMicroHistory,
       InpUseMicro, InpMicroDepth, InpMicroDeviation, InpMicroBackstep, InpMicroStyle, InpMicroWidth, InpMicroColorR1, InpMicroColorS1,
       InpUseSecondary, InpSecDepth, InpSecDeviation, InpSecBackstep, InpSecStyle, InpSecWidth, InpSecColorR1, InpSecColorS1,
       InpUseTertiary, InpTerDepth, InpTerDeviation, InpTerBackstep, InpTerStyle, InpTerWidth, InpTerColorR1, InpTerColorS1,
       InpTrendFastPeriod, InpTrendSlowPeriod, InpTrendMethod
   );

   if(init_ok) {
       m_nav_system.AttachToChart(0);
   }

   m_black_box.Initialize(_Symbol, "v2.16"); // Update Log Version

   if (HistorySelect(0, TimeCurrent())) {
       int total = HistoryDealsTotal();
       if (total > 0) {
           ulong ticket = HistoryDealGetTicket(total - 1);
           g_last_deal_ticket = ticket;
           g_last_deal_time_msc = HistoryDealGetInteger(ticket, DEAL_TIME_MSC);
       }
   }

   // Initialize Panel v2.15 with Defaults
   m_panel.Init(Prefix, InpX, InpY, InpBgColor, InpTxtColor,
                InpLotSize, InpSpreadMultStart, InpSpreadMultStep, InpLayers, InpMinSpreadPoints,
                InpVirtualTPCurrency, InpVirtualSLCurrency);
   m_panel.Create();
   m_panel.UpdateUI(GetFloatingPL());

   Print("Merkava v2.16 Initialized (Context Integr. + CSV Expansion).");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   m_panel.Destroy();
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
   m_nav_system.Release();
   m_black_box.CloseLog();
   if(g_book_subscribed) MarketBookRelease(_Symbol);
}

//+------------------------------------------------------------------+
//| Chart Event                                                      |
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
   }

   // Always Update UI
   m_panel.UpdateUI(GetFloatingPL());
}

string GetNetLotDirection(double &total_lots) {
    double net = 0.0; total_lots = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Magic()==InpMagicNumber) {
           total_lots += m_position.Volume();
           if(m_position.PositionType()==POSITION_TYPE_BUY) net+=m_position.Volume(); else net-=m_position.Volume();
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
       if(m_position.SelectByIndex(i) && m_position.Magic()==InpMagicNumber) {
           if(c > 0) s += "|";
           string t = (m_position.PositionType()==POSITION_TYPE_BUY) ? "B" : "S";
           s += t + ":" + DoubleToString(m_position.StopLoss(),_Digits) + "/" + DoubleToString(m_position.TakeProfit(),_Digits);
           c++; if(c>=3) { s+="|..."; break; }
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

//+------------------------------------------------------------------+
//| Tick Loop                                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   // 1. Physics & Nav
   m_physics.Update(tick);
   PhysicsState p = m_physics.GetState();
   m_nav_system.Refresh(_Symbol, tick);

   // 2. Deal History
   CheckForNewDeals();

   // 3. Profit Management (New v2.15)
   int closed = m_profit_manager.Check();
   if(closed > 0) {
       g_last_action = "VIRTUAL_TP_SL_HIT";
       g_decision_log += "Closed " + IntegerToString(closed) + " positions via Virtual Manager;";
   }

   // 4. Update Panel
   double float_pl = GetFloatingPL();
   m_panel.UpdateUI(float_pl); // Update P/L

   // v2.15: Update Account Stats
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double total_hist_pl = CalculateTotalHistoryProfit();

   m_panel.UpdateAccountStats(balance, equity, margin, free_margin, margin_level, total_hist_pl, g_session_realized_pl);

   MqlBookInfo book[];
   double bid_vol = 0;
   double ask_vol = 0;
   if (g_book_subscribed && MarketBookGet(_Symbol, book)) {
       int size = ArraySize(book);
       for(int i=0; i<size; i++) {
           if((book[i].type == BOOK_TYPE_SELL) && (book[i].price == m_symbol.Ask())) ask_vol += (double)book[i].volume;
           if((book[i].type == BOOK_TYPE_BUY) && (book[i].price == m_symbol.Bid())) bid_vol += (double)book[i].volume;
       }
   }

   MqlRates rates[];
   double b_o=0, b_h=0, b_l=0, b_c=0;
   if(CopyRates(_Symbol, PERIOD_M1, 0, 1, rates) > 0) {
       b_o = rates[0].open; b_h = rates[0].high; b_l = rates[0].low; b_c = rates[0].close;
   }

   double total_lots = 0;
   string lot_dir = GetNetLotDirection(total_lots);
   string verdict = DetermineVerdict(p.velocity, float_pl);

   if (g_transaction_buffer == "") g_transaction_buffer = "NONE";
   if (g_decision_log != "") g_transaction_buffer += "|" + g_decision_log;

   m_black_box.RecordTick(
       tick.time_msc,
       g_last_action, 0, verdict,
       tick.bid, tick.ask, p.spread_avg,
       (long)bid_vol, (long)ask_vol,
       b_o, b_h, b_l, b_c,
       m_nav_system.GetRSI(), p.velocity, p.acceleration,
       m_nav_system.GetHybridMACD(), m_nav_system.GetPulse(),
       m_nav_system.GetFlowMFI(), m_nav_system.GetFlowROC(), m_nav_system.GetFlowDelta(),
       m_nav_system.GetMicP(), m_nav_system.GetMicR(), m_nav_system.GetMicS(),
       m_nav_system.GetSecP(), m_nav_system.GetSecR(), m_nav_system.GetSecS(),
       m_nav_system.GetTerP(), m_nav_system.GetTerR(), m_nav_system.GetTerS(),
       m_nav_system.GetTrendFast(), m_nav_system.GetTrendSlow(),
       balance, margin, margin_level,
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
