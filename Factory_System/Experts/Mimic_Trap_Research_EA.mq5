//+------------------------------------------------------------------+
//|                                   Mimic_Trap_Research_EA.mq5     |
//|                                                      Jules Agent |
//|                       Focused Strategy: Liquidity Mimicry Trap   |
//|                       Mode: RESEARCH & DATA MINING               |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include "../Indicators/PhysicsEngine.mqh"

//--- Objects
CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
PhysicsEngine m_physics(50);

//--- Enums
enum ENUM_DRAWING_STYLE
  {
   STYLE_DRAW_LINE   =  DRAW_COLOR_LINE,     // Line
   STYLE_DRAW_HIST   =  DRAW_COLOR_HISTOGRAM // Histogramm
  };

//--- Inputs
input group "Strategy Settings"
input int           InpTriggerTicks      = 2;      // Consecutive ticks to trigger
input int           InpDecoyCount        = 3;      // Number of Decoy trades
input int           InpTimeoutSec        = 60;     // Auto-reset trap after N seconds
input int           InpPostEventTicks    = 30;     // Ticks to log after Trap Execution
input string        InpIndPath           = "Jules\\"; // Indicator Path (relative to MQL5/Indicators)

input group "Position Size"
input double        InpDecoyLot          = 0.01;   // Decoy Lot (Fake Direction)
input double        InpTrojanLot         = 0.1;    // Trojan Lot (Real Direction)

input group "Risk Management"
input int           InpSlippage          = 10;
input ulong         InpMagicNumber       = 999002; // Updated Magic for Research
input string        InpComment           = "MimicResearch";

input group              "--- WVF Settings ---"
input uint               WVF_InpPeriod      =  22;               // Period
input ENUM_DRAWING_STYLE WVF_InpDrawingType =  STYLE_DRAW_LINE;  // Drawing style

input group              "=== DEMA Settings ==="
input uint               InpFastPeriod         = 5;
input uint               InpSlowPeriod         = 13;
input double             InpDemaGain           = 1.0;    // EMA Mode

input group              "=== Normalization ==="
input uint               InpNormPeriod         = 500;
input double             InpNormSensitivity    = 1.0;

input group              "=== Phase Advance ==="
input double             InpPhaseAdvance       = 2.0;    // High Aggression
input uint               InpSmartSmooth        = 3;      // Velocity Smoothing for Smart Mode

input group              "--- VELOCITY & ACCEL (VA) Settings ---"
input uint               VA_InpPeriodV         = 14;          // Velocity period
input uint               VA_InpPeriodA         = 10;          // Acceleration period
input ENUM_APPLIED_PRICE VA_InpAppliedPrice    = PRICE_CLOSE; // Applied price

input group "Panel UI"
input int           InpX                 = 10;
input int           InpY                 = 80;
input color         InpBgColor           = clrDarkSlateGray;
input color         InpTxtColor          = clrWhite;

//--- Globals
bool              g_trap_active = false;
ENUM_ORDER_TYPE   g_trap_direction = ORDER_TYPE_BUY; // The INTENDED Winner
int               g_trap_counter_ticks = 0;
ulong             g_trap_expire_time = 0;
double            g_last_price = 0.0;
int               g_log_handle = INVALID_HANDLE;
bool              g_book_subscribed = false;

// Research Globals
int               h_wvf = INVALID_HANDLE;
int               h_conviction = INVALID_HANDLE;
int               h_va = INVALID_HANDLE;
double            buf_wvf[], buf_va_v[], buf_va_a[];
double            buf_conv_legacy[], buf_conv_smart[];
string            g_current_phase = "IDLE";
int               g_post_event_counter = 0;
double            g_last_realized_pl = 0.0; // P/L from closed deals this tick

//--- Struct to hold simplified level data
struct LevelData {
   double price;
   long volume;
};

//--- GUI Objects
string Prefix = "MimicRes_";
string ObjBG = Prefix + "BG";
string ObjStat = Prefix + "Status";
string ObjBtnTrapBuy = Prefix + "BtnTrapBuy";
string ObjBtnTrapSell = Prefix + "BtnTrapSell";
string ObjBtnCloseAll = Prefix + "BtnClose";

//--- Forward Declarations
void CreatePanel();
void UpdateUI();
void DestroyPanel();
void CleanupChart();
void DrawDealVisuals(ulong deal_ticket);
void ArmTrap(ENUM_ORDER_TYPE dir);
void ExecuteTrap();
void CloseAll();
double NormalizeLot(double lot);
void WriteLog();
string GetDOMSnapshot();
void SortBids(LevelData &arr[], int count);
void SortAsks(LevelData &arr[], int count);
double GetFloatingPL();

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetDeviationInPoints(InpSlippage);

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;
   else Print("Mimic: Failed to subscribe to MarketBook!");

   // --- INDICATOR HANDLES ---
   // Construct Paths
   string path_wvf = InpIndPath + "WVF";
   string path_conv = InpIndPath + "Hybrid_Conviction_Monitor";
   string path_va = InpIndPath + "Hybrid_Velocity_Acceleration_VA";

   // WVF (Showcase)
   h_wvf = iCustom(_Symbol, _Period, path_wvf,
                   WVF_InpPeriod,
                   WVF_InpDrawingType // Passed as ENUM, strict typing
                   );

   if(h_wvf == INVALID_HANDLE) {
       Print("Failed to load WVF! Path: ", path_wvf);
       Print("Error: ", GetLastError());
       return INIT_FAILED;
   }

   // Visualize WVF
   if(!ChartIndicatorAdd(0, 1, h_wvf)) {
       Print("Failed to add WVF to chart! Error: ", GetLastError());
   }

   // Hybrid Conviction Monitor
   // Inputs: uint, uint, double, uint, double, double, uint
   // Explicit casting to ensure correct varargs alignment
   h_conviction = iCustom(_Symbol, _Period, path_conv,
                          (uint)InpFastPeriod,
                          (uint)InpSlowPeriod,
                          (double)InpDemaGain,
                          (uint)InpNormPeriod,
                          (double)InpNormSensitivity,
                          (double)InpPhaseAdvance,
                          (uint)InpSmartSmooth
                          );

   if(h_conviction == INVALID_HANDLE) {
       Print("Failed to load Conviction! Path: ", path_conv);
       Print("Error: ", GetLastError());
       return INIT_FAILED;
   }

   // Visualize Conviction (Subwindow 2)
   if(!ChartIndicatorAdd(0, 2, h_conviction)) {
       Print("Failed to add Conviction to chart! Error: ", GetLastError());
   }

   // Velocity & Acceleration (VA)
   h_va = iCustom(_Symbol, _Period, path_va,
                  VA_InpPeriodV,
                  VA_InpPeriodA,
                  VA_InpAppliedPrice
                  );

   if(h_va == INVALID_HANDLE) {
       Print("Failed to load VA! Path: ", path_va);
       Print("Error: ", GetLastError());
       return INIT_FAILED;
   }

   // Visualize VA (Subwindow 3)
   if(!ChartIndicatorAdd(0, 3, h_va)) {
       Print("Failed to add VA to chart! Error: ", GetLastError());
   }


   // Init Log (Session Based)
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(time_str, ":", "");
   StringReplace(time_str, " ", "_");
   StringReplace(time_str, ".", "");
   string filename = "Mimic_Research_" + _Symbol + "_" + time_str + ".csv";

   ResetLastError();
   g_log_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

   if(g_log_handle != INVALID_HANDLE)
     {
      // Header
      string header = "Time,TickMS,Phase,Bid,Ask,Spread,Velocity,Acceleration,WVF_Val,Conv_Legacy,Conv_Smart,Ext_VA_Vel,Ext_VA_Acc,Floating_PL,Realized_PL,Action,DOM_Snapshot\r\n";
      FileWriteString(g_log_handle, header);
      FileFlush(g_log_handle);
      Print("Mimic Research: Log file created: ", filename);
     }

   // --- CLEANUP & HYGIENE ---
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false); // No ghost objects
   CleanupChart();

   CreatePanel();
   UpdateUI();

   Print("Mimic Trap Research EA v2.0 Initialized.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DestroyPanel();
   CleanupChart();

   // Remove Visualized Indicators
   ChartIndicatorDelete(0, 1, "WVF");
   ChartIndicatorDelete(0, 2, "Hybrid Conviction Monitor");
   ChartIndicatorDelete(0, 3, "VA");

   if(g_book_subscribed) MarketBookRelease(_Symbol);
   if(h_wvf != INVALID_HANDLE) IndicatorRelease(h_wvf);
   if(h_conviction != INVALID_HANDLE) IndicatorRelease(h_conviction);
   if(h_va != INVALID_HANDLE) IndicatorRelease(h_va);
   if(g_log_handle != INVALID_HANDLE) FileClose(g_log_handle);
  }

void CleanupChart()
  {
   // Delete EA UI
   ObjectsDeleteAll(0, Prefix);

   // Delete Trade History Objects (Start with # or Standard Arrows)
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, "#") == 0 ||
         ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_ARROW_BUY ||
         ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_ARROW_SELL)
        {
         ObjectDelete(0, name);
        }
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Chart Event                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == ObjBtnTrapBuy)
        {
         // Visual Click Feedback
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         PlaySound("tick.wav");
         ArmTrap(ORDER_TYPE_BUY);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == ObjBtnTrapSell)
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         PlaySound("tick.wav");
         ArmTrap(ORDER_TYPE_SELL);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == ObjBtnCloseAll)
        {
         g_trap_active = false; // Disarm
         g_current_phase = "IDLE";
         CloseAll();
         UpdateUI();
        }
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//| Main Tick Loop                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick)) {
      m_physics.Update(tick);
   }

   m_symbol.RefreshRates();
   double bid = m_symbol.Bid();

   // Initialize Last Price
   if(g_last_price == 0.0) { g_last_price = bid; return; }

   // --- TRAP LOGIC ---
   if(g_trap_active)
     {
      // Check Timeout
      if(GetTickCount() > g_trap_expire_time) {
         g_trap_active = false;
         g_current_phase = "IDLE";
         Print("Mimic: Trap Timeout. Reset.");
         PlaySound("timeout.wav");
         UpdateUI();
         // Continue to log this tick
      }
      else
      {
          // Check Price Movement
          if(bid != g_last_price)
            {
             bool price_up = (bid > g_last_price);
             bool price_down = (bid < g_last_price);

             // LOGIC: Wait for movement AGAINST the intended direction
             bool counter_move = (g_trap_direction == ORDER_TYPE_BUY && price_down) ||
                                 (g_trap_direction == ORDER_TYPE_SELL && price_up);

             if(counter_move) {
                g_trap_counter_ticks++;
                Print("Mimic: Counter Tick ", g_trap_counter_ticks, "/", InpTriggerTicks);
                if(g_trap_counter_ticks >= InpTriggerTicks) {
                   ExecuteTrap();
                }
             } else {
                // Reset if momentum breaks
                g_trap_counter_ticks = 0;
             }
            }
      }
     }

   // --- POST EVENT COUNTER ---
   if (g_current_phase == "POST_ANALYSIS") {
       if (bid != g_last_price) { // Count only price ticks
           g_post_event_counter--;
           if (g_post_event_counter <= 0) {
               g_current_phase = "IDLE";
               Print("Mimic: Post-Event Analysis Complete.");
           }
       }
   }

   // --- LOGGING (ALWAYS RUNS) ---
   WriteLog();

   // Reset "One-Shot" variables
   g_last_realized_pl = 0.0;
   g_last_price = bid;
  }

//+------------------------------------------------------------------+
//| Trade Transaction (Visualization & P/L)                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   // Visualization
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      DrawDealVisuals(trans.deal);

      // Check for Exit P/L
      long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
          double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
          double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
          double comm = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
          g_last_realized_pl += (profit + swap + comm);
      }
     }
  }

//+------------------------------------------------------------------+
//| Strategy Functions                                               |
//+------------------------------------------------------------------+
void ArmTrap(ENUM_ORDER_TYPE dir)
  {
   g_trap_active = true;
   g_current_phase = "ARMED";
   g_trap_direction = dir;
   g_trap_counter_ticks = 0;
   g_trap_expire_time = GetTickCount() + (InpTimeoutSec * 1000);
   UpdateUI();

   string d = (dir==ORDER_TYPE_BUY) ? "BUY" : "SELL";
   Print("Mimic: TRAP ARMED for ", d, ". Waiting for ", InpTriggerTicks, " counter ticks.");
  }

void ExecuteTrap()
  {
   g_trap_active = false; // Disarm
   g_current_phase = "TRAP_EXEC";

   // 1. DECOY PHASE (Opposite Direction)
   ENUM_ORDER_TYPE decoy_dir = (g_trap_direction == ORDER_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   double d_lot = NormalizeLot(InpDecoyLot);

   for(int i=0; i<InpDecoyCount; i++) {
      if(m_trade.PositionOpen(_Symbol, decoy_dir, d_lot, (decoy_dir==ORDER_TYPE_BUY)?m_symbol.Ask():m_symbol.Bid(), 0, 0, InpComment+"_Decoy")) {
         Sleep(20); // Minimal spacing
      }
   }

   // 2. TROJAN PHASE (Real Direction)
   double t_lot = NormalizeLot(InpTrojanLot);
   if(m_trade.PositionOpen(_Symbol, g_trap_direction, t_lot, (g_trap_direction==ORDER_TYPE_BUY)?m_symbol.Ask():m_symbol.Bid(), 0, 0, InpComment+"_Trojan")) {
       // Done
   }

   PlaySound("ok.wav");
   Print("Mimic: TRAP EXECUTED!");

   // Set Post-Event Phase
   g_current_phase = "POST_ANALYSIS";
   g_post_event_counter = InpPostEventTicks;

   UpdateUI();
  }

void CloseAll()
  {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber) {
         m_trade.PositionClose(m_position.Ticket());
      }
   }
   Print("Mimic: All positions closed.");
  }

//+------------------------------------------------------------------+
//| GUI                                                              |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   // Background
   ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, InpX);
   ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, InpY);
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, 160);
   ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, 130);
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   // Status Label
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, InpY+5);
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, InpTxtColor);
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "READY");

   // Buttons
   // Row 1: TRAP BUY (Green)
   ObjectCreate(0, ObjBtnTrapBuy, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_YDISTANCE, InpY+30);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ObjBtnTrapBuy, OBJPROP_TEXT, "TRAP BUY (Wait Dip)");
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_BGCOLOR, clrForestGreen);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_COLOR, clrWhite);

   // Row 2: TRAP SELL (Red)
   ObjectCreate(0, ObjBtnTrapSell, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_YDISTANCE, InpY+65);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ObjBtnTrapSell, OBJPROP_TEXT, "TRAP SELL (Wait Rise)");
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_BGCOLOR, clrFireBrick);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_COLOR, clrWhite);

   // Row 3: CLOSE ALL
   ObjectCreate(0, ObjBtnCloseAll, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_XDISTANCE, InpX+10);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_YDISTANCE, InpY+100);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_YSIZE, 20);
   ObjectSetString(0, ObjBtnCloseAll, OBJPROP_TEXT, "CLOSE ALL / RESET");
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_BGCOLOR, clrDimGray);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_COLOR, clrWhite);
  }

void UpdateUI()
  {
   string status_text = g_current_phase;
   if(g_trap_active) {
       string dir = (g_trap_direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
       status_text = "ARMED: " + dir + " (" + IntegerToString(g_trap_counter_ticks) + "/" + IntegerToString(InpTriggerTicks) + ")";
   }
   else if (g_current_phase == "POST_ANALYSIS") {
       status_text = "LOGGING: " + IntegerToString(g_post_event_counter);
   }

   ObjectSetString(0, ObjStat, OBJPROP_TEXT, status_text);

   if (g_trap_active) {
       string dir = (g_trap_direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
       ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_BGCOLOR, (dir=="BUY") ? clrOrange : clrDimGray);
       ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_BGCOLOR, (dir=="SELL") ? clrOrange : clrDimGray);
   } else {
       ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_BGCOLOR, clrForestGreen);
       ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_BGCOLOR, clrFireBrick);
   }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Logging & Physics                                                |
//+------------------------------------------------------------------+
void WriteLog()
  {
   if(g_log_handle == INVALID_HANDLE) return;

   // 1. Get Indicator Values
   double wvf_val = 0;
   double conv_leg = 0;
   double conv_smart = 0;

   // WVF (0=Value)
   double buf[1];
   if(CopyBuffer(h_wvf, 0, 0, 1, buf)>0) wvf_val = buf[0];

   // Conviction (0=Legacy, 1=Smart)
   if(CopyBuffer(h_conviction, 0, 0, 1, buf)>0) conv_leg = buf[0];
   if(CopyBuffer(h_conviction, 1, 0, 1, buf)>0) conv_smart = buf[0];

   // VA (0=Vel, 1=Acc)
   double va_v=0, va_a=0;
   if(CopyBuffer(h_va, 0, 0, 1, buf)>0) va_v = buf[0];
   if(CopyBuffer(h_va, 1, 0, 1, buf)>0) va_a = buf[0];

   // 2. Physics
   PhysicsState p = m_physics.GetState();

   // 3. P/L
   double float_pl = GetFloatingPL();

   // 4. Time
   string t = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string ms = IntegerToString(GetTickCount()%1000);

   // Format Updated for WVF + Conviction
   string row = StringFormat("%s,%s,%s,%.5f,%.5f,%.1f,%.5f,%.5f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%s",
       t, ms, g_current_phase,
       m_symbol.Bid(), m_symbol.Ask(), p.spread_avg,
       p.velocity, p.acceleration,
       wvf_val,
       conv_leg, conv_smart,
       va_v, va_a,
       float_pl, g_last_realized_pl,
       InpComment
   );

   string dom_part = GetDOMSnapshot();
   FileWriteString(g_log_handle, row + "," + dom_part + "\r\n");
   FileFlush(g_log_handle);
  }

double GetFloatingPL()
{
    double pl = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber) {
           pl += m_position.Profit() + m_position.Swap() + m_position.Commission();
       }
    }
    return pl;
}

string GetDOMSnapshot()
  {
   MqlBookInfo book[];
   LevelData bids[]; LevelData asks[];
   double best_bid=0, best_ask=0;
   long bid_v[5]={0}, ask_v[5]={0};

   if(g_book_subscribed && MarketBookGet(_Symbol, book))
     {
      int size = ArraySize(book);
      ArrayResize(bids, size); ArrayResize(asks, size);
      int b=0, a=0;
      for(int i=0; i<size; i++) {
         if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET) { bids[b].price=book[i].price; bids[b].volume=book[i].volume; b++; }
         else if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET) { asks[a].price=book[i].price; asks[a].volume=book[i].volume; a++; }
      }
      SortBids(bids, b); SortAsks(asks, a);
      if(b>0) best_bid=bids[0].price;
      if(a>0) best_ask=asks[0].price;
      for(int i=0; i<5; i++) {
         if(i<b) bid_v[i]=bids[i].volume;
         if(i<a) ask_v[i]=asks[i].volume;
      }
     }

   string s = DoubleToString(best_bid,_Digits)+","+DoubleToString(best_ask,_Digits)+",";
   for(int i=0;i<5;i++) s+=IntegerToString(bid_v[i])+",";
   for(int i=0;i<5;i++) { s+=IntegerToString(ask_v[i]); if(i<4) s+=","; }
   return s;
  }

void SortBids(LevelData &arr[], int count) {
   for(int i=0; i<count-1; i++) for(int j=0; j<count-i-1; j++) if(arr[j].price < arr[j+1].price) { LevelData t=arr[j]; arr[j]=arr[j+1]; arr[j+1]=t; }
}
void SortAsks(LevelData &arr[], int count) {
   for(int i=0; i<count-1; i++) for(int j=0; j<count-i-1; j++) if(arr[j].price > arr[j+1].price) { LevelData t=arr[j]; arr[j]=arr[j+1]; arr[j+1]=t; }
}

void DestroyPanel()
  {
   ObjectDelete(0, ObjBG);
   ObjectDelete(0, ObjStat);
   ObjectDelete(0, ObjBtnTrapBuy);
   ObjectDelete(0, ObjBtnTrapSell);
   ObjectDelete(0, ObjBtnCloseAll);
  }

double NormalizeLot(double lot)
  {
   double step = m_symbol.LotsStep();
   double min = m_symbol.LotsMin();
   double max = m_symbol.LotsMax();
   if(step > 0) lot = MathFloor(lot / step) * step;
   if(lot < min) lot = min;
   if(lot > max) lot = max;
   return lot;
  }

void DrawDealVisuals(ulong deal_ticket)
  {
   if(!HistoryDealSelect(deal_ticket)) return;
   long entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   long type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   double price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   long time = HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   string name = Prefix + "Arrow_" + (string)deal_ticket;

   if(entry == DEAL_ENTRY_IN) {
      ENUM_OBJECT obj_type = (type == DEAL_TYPE_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      ObjectCreate(0, name, obj_type, 0, (datetime)time, price);
   } else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
      ENUM_OBJECT obj_type = (type == DEAL_TYPE_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      if(ObjectCreate(0, name, obj_type, 0, (datetime)time, price))
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
   }
   ChartRedraw();
  }
