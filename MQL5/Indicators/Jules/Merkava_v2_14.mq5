//+------------------------------------------------------------------+
//|                                                Merkava_v2_14.mq5 |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 2.14   |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "2.14"
#property strict

#include "../Indicators/Types_v2_14.mqh" // Types first
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <AccountInfo.mqh>

// Library Organization (v2.14)
#include "../Indicators/FireControl_v2_14.mqh"
#include "../Indicators/PanelControl_v2_14.mqh"
#include "../Indicators/PhysicsEngine.mqh"
#include "../Indicators/NavSystem_v2_06.mqh"
#include "../Indicators/BlackBox_v2_05.mqh"

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
input ulong         InpMagicNumber       = 999014; // Updated Magic v2.14
input string        InpComment           = "Merkava_v2.14";

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

   // v2.14: Initialize FireControl with pointers
   m_fire_control.Init(&m_trade, &m_symbol, InpComment, InpMagicNumber);

   bool init_ok = m_nav_system.Initialize(
       _Symbol, _Period,
       InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.05", // v2.06: Point to v1.05
       Hybrid_FastEMA, Hybrid_SlowEMA, 20, 2.0, MODE_EMA,
       20, 1.5, 10, MODE_EMA,
       Hybrid_MACDScale, 0, Hybrid_DFScale, Hybrid_AutoScaling, 100,
       Hybrid_Divisor, // v2.06: Pass Divisor
       InpIndPath + "HybridFlowIndicator_v1.125",
       false, -100, 200, Flow_MFIPeriod, true, Flow_VROCPeriod, 20.0, true,
       Flow_Smooth, Flow_NormLen, Flow_Scale, 3.0
   );

   if(init_ok) {
       m_nav_system.AttachToChart(0);
   }

   m_black_box.Initialize(_Symbol, "v2.14"); // Update Log Version

   if (HistorySelect(0, TimeCurrent())) {
       int total = HistoryDealsTotal();
       if (total > 0) {
           ulong ticket = HistoryDealGetTicket(total - 1);
           g_last_deal_ticket = ticket;
           g_last_deal_time_msc = HistoryDealGetInteger(ticket, DEAL_TIME_MSC);
       }
   }

   // Initialize Panel v2.14
   m_panel.Init(Prefix, InpX, InpY, InpBgColor, InpTxtColor,
                InpLotSize, InpSpreadMultStart, InpSpreadMultStep, InpLayers, InpMinSpreadPoints);
   m_panel.Create();
   m_panel.UpdateUI(GetFloatingPL());

   Print("Merkava v2.14 Initialized (Dual Mode + Instant Entry + PanelControl + Solo/Combo).");
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

   if (event == EVENT_FIRE)
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
       ENUM_ATTACK_DIR dir = m_panel.GetAttackDir();
       ENUM_ACTION_TYPE action = m_panel.GetActionType();

       m_fire_control.FireGrid(center, lot, layers, mstart, mstep, mindist, mode, entry, dir, action);

       g_last_action = (mode == FIRE_MODE_STOP) ? "TRAP_SET" : "LIMIT_GRID";
       if (entry == ENTRY_MARKET) g_last_action += "_INSTANT";
       if (action == ACTION_SOLO) g_last_action += "_SOLO";

       g_decision_log += "Grid Fired L" + IntegerToString(layers) + " (" + ((mode==FIRE_MODE_STOP)?"Breakout":"Reversion") + "/" + ((entry==ENTRY_MARKET)?"Market":"Pending") + ");";
   }
   else if (event == EVENT_CEASE_FIRE)
   {
       m_fire_control.CeaseFire();
       g_last_action = "CEASE_FIRE";
       g_decision_log += "Cease Fire;";
   }
   else if (event == EVENT_PARAM_UPDATE)
   {
       PrintFormat("Merkava Params Updated: Lot=%.2f, MultStart=%.1f, MultStep=%.1f, Layers=%d",
                  m_panel.GetLotSize(), m_panel.GetMultStart(), m_panel.GetMultStep(), m_panel.GetLayers());
   }

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

   m_physics.Update(tick);
   PhysicsState p = m_physics.GetState();

   m_nav_system.Refresh(_Symbol, tick);

   CheckForNewDeals();

   double float_pl = GetFloatingPL();

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

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double margin_lev = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

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
       balance, margin, margin_lev,
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
