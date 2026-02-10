//+------------------------------------------------------------------+
//|                                                Merkava_v2_11.mq5 |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                             For Project Merkava  |
//|                                                   Version 2.11   |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "2.11"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <AccountInfo.mqh>

// Library Organization (v2.11)
#include "../Indicators/FireControl_v2_11.mqh" // v2.11: Dual Mode (Stop/Limit)
#include "../Indicators/PhysicsEngine.mqh"
#include "../Indicators/NavSystem_v2_06.mqh" // v2.06: Hybrid Divisor Logic
#include "../Indicators/BlackBox_v2_05.mqh" // v2.05: Keep existing

//--- Objects
CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
CAccountInfo  m_account;

PhysicsEngine m_physics(50);
CFireControl  m_fire_control;
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
input ulong         InpMagicNumber       = 999011; // Updated Magic v2.11
input string        InpComment           = "Merkava_v2.11";

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

// User Configurable Runtime Globals
double            g_user_lot_size;
double            g_user_mult_start;
double            g_user_mult_step;
int               g_user_layers;
double            g_user_min_dist;
int               g_user_fire_mode = 1; // Default to STOP (Breakout) = 1. Limit = 0.

string            g_last_action = "IDLE";
double            g_last_realized_pl = 0.0;
double            g_session_realized_pl = 0.0;
string            g_tick_event_buffer = "";
string            g_decision_log = "";
string            g_transaction_buffer = "";

ulong             g_last_deal_ticket = 0;
long              g_last_deal_time_msc = 0;

//--- GUI Objects
string Prefix = "MerkavaV2_";
string ObjBG = Prefix + "BG";
string ObjStat = Prefix + "Status";
string ObjBtnFire = Prefix + "BtnFire";
string ObjBtnClear = Prefix + "BtnClear";
string ObjBtnMode = Prefix + "BtnMode"; // New Toggle Button

string ObjLabelLot = Prefix + "LabelLot";
string ObjEditLot = Prefix + "EditLot";

string ObjLabelMultStart = Prefix + "LabelMultStart";
string ObjEditMultStart = Prefix + "EditMultStart";

string ObjLabelMultStep = Prefix + "LabelMultStep";
string ObjEditMultStep = Prefix + "EditMultStep";

string ObjLabelLayers = Prefix + "LabelLayers";
string ObjEditLayers = Prefix + "EditLayers";

string ObjLabelMinDist = Prefix + "LabelMinDist";
string ObjEditMinDist = Prefix + "EditMinDist";

string ObjLabelPL = Prefix + "LabelPL";

//--- Forward Declarations
void CreatePanel();
void UpdateUI();
void DestroyPanel();
void CleanupChart();
void CheckForNewDeals();
double GetFloatingPL();
string GetNetLotDirection(double &total_lots);
string GetSLTPSnapshot();
string DetermineVerdict(double velocity, double pl);
void UpdateModeButton();

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   CleanupChart();
   m_nav_system.Release();
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetDeviationInPoints(InpSlippage);

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;

   // Initialize User Globals from Inputs
   g_user_lot_size = InpLotSize;
   g_user_mult_start = InpSpreadMultStart;
   g_user_mult_step = InpSpreadMultStep;
   g_user_layers = InpLayers;
   g_user_min_dist = InpMinSpreadPoints;
   g_user_fire_mode = 1; // Default: Breakout (Stop)

   // v2.11: Initialize FireControl with pointers
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

   m_black_box.Initialize(_Symbol, "v2.11"); // Update Log Version

   if (HistorySelect(0, TimeCurrent())) {
       int total = HistoryDealsTotal();
       if (total > 0) {
           ulong ticket = HistoryDealGetTicket(total - 1);
           g_last_deal_ticket = ticket;
           g_last_deal_time_msc = HistoryDealGetInteger(ticket, DEAL_TIME_MSC);
       }
   }

   CreatePanel();
   UpdateUI();

   Print("Merkava v2.11 Initialized (Dual Mode + Full GUI Control).");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DestroyPanel();
   CleanupChart();
   m_nav_system.Release();
   m_black_box.CloseLog();
   if(g_book_subscribed) MarketBookRelease(_Symbol);
}

void CleanupChart()
{
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Chart Event                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == ObjBtnFire)
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         ChartRedraw();

         double center = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;

         // v2.11: Use Dual Mode FireGrid
         ENUM_FIRE_MODE mode = (g_user_fire_mode == 1) ? FIRE_MODE_STOP : FIRE_MODE_LIMIT;
         m_fire_control.FireGrid(center, g_user_lot_size, g_user_layers, g_user_mult_start, g_user_mult_step, g_user_min_dist, mode);

         g_last_action = (mode == FIRE_MODE_STOP) ? "TRAP_SET" : "LIMIT_GRID";
         g_decision_log += "Grid Fired L" + IntegerToString(g_user_layers) + " (" + ((mode==FIRE_MODE_STOP)?"Breakout":"Reversion") + ");";

         Sleep(100);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if (sparam == ObjBtnClear)
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         m_fire_control.CeaseFire();
         g_last_action = "CEASE_FIRE";
         g_decision_log += "Cease Fire;";
         Sleep(100);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if (sparam == ObjBtnMode)
      {
         // Toggle Mode
         if(g_user_fire_mode == 1) g_user_fire_mode = 0; // Switch to Limit
         else g_user_fire_mode = 1; // Switch to Stop
         UpdateModeButton();
      }
      UpdateUI();
   }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      // Handle UI Updates
      if(sparam == ObjEditLot) {
           double val = StringToDouble(ObjectGetString(0, ObjEditLot, OBJPROP_TEXT));
           if(val > 0) g_user_lot_size = val;
      }
      else if(sparam == ObjEditMultStart) {
           double val = StringToDouble(ObjectGetString(0, ObjEditMultStart, OBJPROP_TEXT));
           if(val > 0) g_user_mult_start = val;
      }
      else if(sparam == ObjEditMultStep) {
           double val = StringToDouble(ObjectGetString(0, ObjEditMultStep, OBJPROP_TEXT));
           if(val > 0) g_user_mult_step = val;
      }
      else if(sparam == ObjEditLayers) {
           long val = StringToInteger(ObjectGetString(0, ObjEditLayers, OBJPROP_TEXT));
           if(val > 0 && val < 20) g_user_layers = (int)val;
      }
      else if(sparam == ObjEditMinDist) {
           double val = StringToDouble(ObjectGetString(0, ObjEditMinDist, OBJPROP_TEXT));
           if(val >= 0) g_user_min_dist = val;
      }

      PrintFormat("Merkava Params Updated: Lot=%.2f, MultStart=%.1f, MultStep=%.1f, Layers=%d, MinDist=%.0f",
                  g_user_lot_size, g_user_mult_start, g_user_mult_step, g_user_layers, g_user_min_dist);
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

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
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

double GetFloatingPL() {
    double pl = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Magic()==InpMagicNumber)
           pl += m_position.Profit() + m_position.Swap() + m_position.Commission();
    }
    return pl;
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

string DetermineVerdict(double v, double pl) {
    if(pl < -50.0 && v > 20.0) return "CRASH_RISK";
    if(pl > 10.0) return "WINNING";
    if(pl < -10.0) return "PRESSURE";
    return "STABLE";
}

//+------------------------------------------------------------------+
//| Panel Construction (v2.11 Expanded + Toggle Mode)                |
//+------------------------------------------------------------------+
void CreatePanel() {
   int x=InpX, y=InpY;
   int w=160;
   int h=360; // Increased height for Toggle Button

   ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, w); ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);

   int cy = y+10;
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, cy);
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "MERKAVA v2.11");
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, clrLime);

   // --- Lot Size ---
   cy+=30;
   ObjectCreate(0, ObjLabelLot, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelLot, OBJPROP_YDISTANCE, cy);
   ObjectSetString(0, ObjLabelLot, OBJPROP_TEXT, "Lot:");
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_COLOR, InpTxtColor);

   ObjectCreate(0, ObjEditLot, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditLot, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditLot, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditLot, OBJPROP_TEXT, DoubleToString(g_user_lot_size, 2));
   ObjectSetInteger(0, ObjEditLot, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditLot, OBJPROP_COLOR, clrBlack);

   // --- Mult Start ---
   cy+=25;
   ObjectCreate(0, ObjLabelMultStart, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_YDISTANCE, cy);
   ObjectSetString(0, ObjLabelMultStart, OBJPROP_TEXT, "Mult Start:");
   ObjectSetInteger(0, ObjLabelMultStart, OBJPROP_COLOR, InpTxtColor);

   ObjectCreate(0, ObjEditMultStart, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditMultStart, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjEditMultStart, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditMultStart, OBJPROP_TEXT, DoubleToString(g_user_mult_start, 1));
   ObjectSetInteger(0, ObjEditMultStart, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMultStart, OBJPROP_COLOR, clrBlack);

   // --- Mult Step ---
   cy+=25;
   ObjectCreate(0, ObjLabelMultStep, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_YDISTANCE, cy);
   ObjectSetString(0, ObjLabelMultStep, OBJPROP_TEXT, "Mult Step:");
   ObjectSetInteger(0, ObjLabelMultStep, OBJPROP_COLOR, InpTxtColor);

   ObjectCreate(0, ObjEditMultStep, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditMultStep, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjEditMultStep, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditMultStep, OBJPROP_TEXT, DoubleToString(g_user_mult_step, 1));
   ObjectSetInteger(0, ObjEditMultStep, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMultStep, OBJPROP_COLOR, clrBlack);

   // --- Layers ---
   cy+=25;
   ObjectCreate(0, ObjLabelLayers, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelLayers, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelLayers, OBJPROP_YDISTANCE, cy);
   ObjectSetString(0, ObjLabelLayers, OBJPROP_TEXT, "Layers:");
   ObjectSetInteger(0, ObjLabelLayers, OBJPROP_COLOR, InpTxtColor);

   ObjectCreate(0, ObjEditLayers, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditLayers, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditLayers, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjEditLayers, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditLayers, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditLayers, OBJPROP_TEXT, IntegerToString(g_user_layers));
   ObjectSetInteger(0, ObjEditLayers, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditLayers, OBJPROP_COLOR, clrBlack);

   // --- Min Dist ---
   cy+=25;
   ObjectCreate(0, ObjLabelMinDist, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_YDISTANCE, cy);
   ObjectSetString(0, ObjLabelMinDist, OBJPROP_TEXT, "Min Dist:");
   ObjectSetInteger(0, ObjLabelMinDist, OBJPROP_COLOR, InpTxtColor);

   ObjectCreate(0, ObjEditMinDist, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditMinDist, OBJPROP_XDISTANCE, x+80); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjEditMinDist, OBJPROP_XSIZE, 60); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditMinDist, OBJPROP_TEXT, DoubleToString(g_user_min_dist, 0));
   ObjectSetInteger(0, ObjEditMinDist, OBJPROP_BGCOLOR, clrWhite); ObjectSetInteger(0, ObjEditMinDist, OBJPROP_COLOR, clrBlack);

   // --- Mode Toggle Button ---
   cy+=30;
   ObjectCreate(0, ObjBtnMode, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnMode, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjBtnMode, OBJPROP_XSIZE, w-20); ObjectSetInteger(0, ObjBtnMode, OBJPROP_YSIZE, 30);
   // Initial State
   ObjectSetString(0, ObjBtnMode, OBJPROP_TEXT, "MODE: BREAKOUT");
   ObjectSetInteger(0, ObjBtnMode, OBJPROP_BGCOLOR, clrOrangeRed); ObjectSetInteger(0, ObjBtnMode, OBJPROP_COLOR, clrWhite);

   // --- Fire Button ---
   cy+=40;
   ObjectCreate(0, ObjBtnFire, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnFire, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_XSIZE, w-20); ObjectSetInteger(0, ObjBtnFire, OBJPROP_YSIZE, 40);
   ObjectSetString(0, ObjBtnFire, OBJPROP_TEXT, "FIRE GRID");
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_BGCOLOR, clrRed); ObjectSetInteger(0, ObjBtnFire, OBJPROP_COLOR, clrWhite);

   // --- Cease Fire ---
   cy+=50;
   ObjectCreate(0, ObjBtnClear, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_XSIZE, w-20); ObjectSetInteger(0, ObjBtnClear, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ObjBtnClear, OBJPROP_TEXT, "CEASE FIRE");
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_BGCOLOR, clrOrange); ObjectSetInteger(0, ObjBtnClear, OBJPROP_COLOR, clrBlack);

   // --- PL Label ---
   cy+=40;
   ObjectCreate(0, ObjLabelPL, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_XDISTANCE, x+10); ObjectSetInteger(0, ObjLabelPL, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrWhite);

   UpdateModeButton(); // Set initial color/text
}

void UpdateModeButton() {
    if(g_user_fire_mode == 1) {
        ObjectSetString(0, ObjBtnMode, OBJPROP_TEXT, "MODE: BREAKOUT (Stop)");
        ObjectSetInteger(0, ObjBtnMode, OBJPROP_BGCOLOR, clrOrangeRed);
    } else {
        ObjectSetString(0, ObjBtnMode, OBJPROP_TEXT, "MODE: REVERSION (Limit)");
        ObjectSetInteger(0, ObjBtnMode, OBJPROP_BGCOLOR, clrCornflowerBlue);
    }
    ChartRedraw();
}
