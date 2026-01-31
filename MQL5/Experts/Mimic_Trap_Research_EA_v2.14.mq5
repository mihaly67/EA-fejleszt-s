//+------------------------------------------------------------------+
//|                                   Mimic_Trap_Research_EA_v2.14.mq5|
//|                                                      Jules Agent |
//|                       Focused Strategy: Liquidity Mimicry Trap   |
//|                       Mode: RESEARCH & DATA MINING (v2.14)       |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "2.14"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include "../Indicators/PhysicsEngine.mqh"
#include <AccountInfo.mqh>

//--- Objects
CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
CAccountInfo  m_account;
PhysicsEngine m_physics(50);

//--- Enums
enum ENUM_DRAWING_STYLE
  {
   STYLE_DRAW_LINE   =  DRAW_COLOR_LINE,     // Line
   STYLE_DRAW_HIST   =  DRAW_COLOR_HISTOGRAM // Histogramm
  };

enum ENUM_COLOR_LOGIC {
    COLOR_SLOPE,     // Slope (Change from Prev Bar) - FASTEST
    COLOR_CROSSOVER, // MACD > Signal (Classic) - LAGGING
    COLOR_ZERO_CROSS // MACD > 0 (Simple)
};

//--- Inputs
// [Strategy Settings]
input int           InpTriggerTicks      = 2;         // [Strategy] Consecutive ticks to trigger
input int           InpDecoyCount        = 3;         // [Strategy] Number of Decoy trades
input int           InpTimeoutSec        = 60;        // [Strategy] Auto-reset trap after N seconds
input int           InpPostEventTicks    = 30;        // [Strategy] Ticks to log after Trap Execution
input string        InpIndPath           = "Jules\\"; // [Strategy] Indicator Path

// [Position Size]
input double        InpDecoyLot          = 0.01;   // [Position] Decoy Lot (Fake Direction)
input double        InpTrojanLot         = 0.1;    // [Position] Trojan Lot (Real Direction)

// [Risk Management]
input int           InpSlippage          = 10;     // [Risk] Slippage
input ulong         InpMagicNumber       = 999002; // [Risk] Magic Number
input string        InpComment           = "MimicResearch"; // [Risk] Comment
input double        InpSLPercent         = 5.0;    // [Risk] Stop Loss % (Default 5%)
input double        InpTPPercent         = 5.0;    // [Risk] Take Profit % (Default 5%)

// [Jules Hybrid Momentum Pulse v1.04 Settings] - FLATTENED
input uint           Hybrid_InpPeriodFastEMA     =  3;          // [Hybrid] MACD Fast EMA period
input uint           Hybrid_InpPeriodSlowEMA     =  6;          // [Hybrid] MACD Slow EMA period
input uint           Hybrid_InpPeriodBB          =  20;         // [Hybrid] Bollinger Bands period
input double         Hybrid_InpDeviationBB       =  2.0;        // [Hybrid] Bollinger Bands deviation
input ENUM_MA_METHOD Hybrid_InpMethodBB          =  MODE_EMA;   // [Hybrid] Bollinger Bands MA method
input uint           Hybrid_InpPeriodKeltner     =  20;         // [Hybrid] Keltner period
input double         Hybrid_InpDeviationKeltner  =  1.5;        // [Hybrid] Keltner deviation
input uint           Hybrid_InpPeriodATRKeltner  =  10;         // [Hybrid] Keltner ATR period
input ENUM_MA_METHOD Hybrid_InpMethodKeltner     =  MODE_EMA;   // [Hybrid] Keltner MA method
input double         Hybrid_InpMACDScale         =  4.0;        // [Hybrid] MACD Scale
input int            Hybrid_InpDFShift           = 0;           // [Hybrid] DF Shift
input double         Hybrid_InpDFScale           = 1.0;         // [Hybrid] DF Manual Scale
input bool           Hybrid_InpUseAutoScaling    = true;        // [Hybrid] DF Auto-Scale
input int            Hybrid_InpAutoScaleLookback = 100;         // [Hybrid] DF Lookback


// [Momentum Settings (Legacy)]
input ENUM_COLOR_LOGIC   Mom_InpColorLogic     = COLOR_SLOPE; // [Momentum] Color Logic Mode
input int                Mom_InpFastPeriod     = 3;           // [Momentum] Fast Period
input int                Mom_InpSlowPeriod     = 6;           // [Momentum] Slow Period
input int                Mom_InpSignalPeriod   = 13;          // [Momentum] Signal Period
input ENUM_APPLIED_PRICE Mom_InpAppliedPrice   = PRICE_CLOSE; // [Momentum] Applied Price
input double             Mom_InpKalmanGain     = 1.0;         // [Momentum] Kalman Gain
input double             Mom_InpPhaseAdvance   = 0.5;         // [Momentum] Phase Advance
input bool               Mom_InpEnableBoost    = true;        // [Momentum] Enable Stochastic Mix
input double             Mom_InpStochMixWeight = 0.2;         // [Momentum] Mixing Weight
input int                Mom_InpStochK         = 5;           // [Momentum] Stochastic K
input int                Mom_InpStochD         = 3;           // [Momentum] Stochastic D
input int                Mom_InpStochSlowing   = 3;           // [Momentum] Stochastic Slowing
input int                Mom_InpNormPeriod     = 100;         // [Momentum] Norm Lookback
input double             Mom_InpNormSensitivity= 1.0;         // [Momentum] Sensitivity

// [Flow Settings]
input bool               Flow_InpUseFixedScale       = false;   // [Flow] Use Fixed Scale?
input double             Flow_InpScaleMin            = -100.0;  // [Flow] Fixed Min
input double             Flow_InpScaleMax            = 200.0;   // [Flow] Fixed Max
input int                Flow_InpMFIPeriod           = 14;      // [Flow] MFI Period
input bool               Flow_InpShowVROC            = true;    // [Flow] Show VROC?
input int                Flow_InpVROCPeriod          = 10;      // [Flow] VROC Period
input double             Flow_InpVROCThreshold       = 20.0;    // [Flow] VROC Alert Threshold %
input bool               Flow_InpUseApproxDelta      = true;    // [Flow] Use Approx Delta
input int                Flow_InpDeltaSmooth         = 3;       // [Flow] Delta Smoothing
input int                Flow_InpNormalizationLen    = 100;     // [Flow] Delta Norm Length
input double             Flow_InpDeltaScaleFactor    = 50.0;    // [Flow] Delta Curve Factor
input double             Flow_InpHistogramVisualGain = 3.0;     // [Flow] Hist Visual Gain

// [Panel UI]
input int           InpX                 = 10;               // [UI] X Coordinate
input int           InpY                 = 20;               // [UI] Y Coordinate (Moved Up for compactness)
input color         InpBgColor           = clrDarkSlateGray; // [UI] BG Color
input color         InpTxtColor          = clrWhite;         // [UI] Text Color

//--- Globals
bool              g_trap_active = false;
ENUM_ORDER_TYPE   g_trap_direction = ORDER_TYPE_BUY; // The INTENDED Winner
int               g_trap_counter_ticks = 0;
ulong             g_trap_expire_time = 0;
double            g_last_price = 0.0;
int               g_log_handle = INVALID_HANDLE;
bool              g_book_subscribed = false;

// Research Globals
int               h_hybrid = INVALID_HANDLE; // NEW: Jules Hybrid Pulse
int               h_momentum = INVALID_HANDLE; // Legacy Momentum
int               h_flow = INVALID_HANDLE; // Filter Flow

string            g_current_phase = "IDLE";
int               g_post_event_counter = 0;
double            g_last_realized_pl = 0.0; // P/L from closed deals this tick
double            g_session_realized_pl = 0.0; // Total Session P/L
string            g_tick_event_buffer = ""; // Stores events for the current tick

// Strategy Control Globals
bool              g_mimic_mode = true; // Default ON
double            g_target_profit_eur = 0.0; // 0 = Disabled
double            g_user_lot_size = InpTrojanLot; // Editable via Panel
int               g_user_burst_count = 5;         // Editable via Panel
int               g_user_burst_delay = 50;        // Editable via Panel

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
string ObjBtnTrapBurst = Prefix + "BtnTrapBurst";
string ObjBtnCloseAll = Prefix + "BtnClose";
string ObjBtnMimicToggle = Prefix + "BtnMimic";

// Editable Fields
string ObjEditTP = Prefix + "EditTP";
string ObjLabelTP = Prefix + "LabelTP";

string ObjEditLot = Prefix + "EditLot";
string ObjLabelLot = Prefix + "LabelLot";

string ObjEditBCount = Prefix + "EditBCount";
string ObjLabelBCount = Prefix + "LabelBCount";

string ObjEditBDelay = Prefix + "EditBDelay";
string ObjLabelBDelay = Prefix + "LabelBDelay";

string ObjLabelPL = Prefix + "LabelPL";

//--- Forward Declarations
void CreatePanel();
void UpdateUI();
void DestroyPanel();
void CleanupChart();
void RemoveIndicators();
void DrawDealVisuals(ulong deal_ticket);
void ArmTrap(ENUM_ORDER_TYPE dir);
void ExecuteTrap();
void ExecuteBurstTrap();
void CloseAll();
double NormalizeLot(double lot);
void WriteLog();
string GetDOMSnapshot();
void SortBids(LevelData &arr[], int count);
void SortAsks(LevelData &arr[], int count);
double GetFloatingPL();
void CalcDailyPivots(double &pp, double &r1, double &s1);
void CalculateSLTP(ENUM_ORDER_TYPE type, double price, double &sl, double &tp);
string GetNetLotDirection();
string GetSLTPSnapshot();
string DetermineVerdict(double velocity, double pl);

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // --- CLEANUP FIRST to prevent duplication ---
   RemoveIndicators();
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);
   CleanupChart();

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetDeviationInPoints(InpSlippage);

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;
   else Print("Mimic: Failed to subscribe to MarketBook!");

   // Initialize User Globals from Inputs
   g_user_lot_size = InpTrojanLot;

   // --- INDICATOR HANDLES ---
   string path_hybrid = InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.04";
   string path_mom = InpIndPath + "HybridMomentumIndicator_v2.82";
   string path_flow = InpIndPath + "HybridFlowIndicator_v1.125";

   // 1. Jules Hybrid Momentum Pulse v1.04 (Subwindow 1)
   h_hybrid = iCustom(_Symbol, _Period, path_hybrid,
                      Hybrid_InpPeriodFastEMA,
                      Hybrid_InpPeriodSlowEMA,
                      Hybrid_InpPeriodBB,
                      Hybrid_InpDeviationBB,
                      Hybrid_InpMethodBB,
                      Hybrid_InpPeriodKeltner,
                      Hybrid_InpDeviationKeltner,
                      Hybrid_InpPeriodATRKeltner,
                      Hybrid_InpMethodKeltner,
                      Hybrid_InpMACDScale,
                      Hybrid_InpDFShift,
                      Hybrid_InpDFScale,
                      Hybrid_InpUseAutoScaling,
                      Hybrid_InpAutoScaleLookback
                      );
   if(h_hybrid != INVALID_HANDLE) ChartIndicatorAdd(0, 1, h_hybrid);
   else Print("Failed to load Hybrid Momentum Pulse v1.04! Path: ", path_hybrid, " Error: ", GetLastError());


   // 2. Filter Flow (Subwindow 2)
   MqlParam flow_params[13];
   flow_params[0].type = TYPE_STRING; flow_params[0].string_value = path_flow;
   flow_params[1].type = TYPE_BOOL;   flow_params[1].integer_value = Flow_InpUseFixedScale;
   flow_params[2].type = TYPE_DOUBLE; flow_params[2].double_value = Flow_InpScaleMin;
   flow_params[3].type = TYPE_DOUBLE; flow_params[3].double_value = Flow_InpScaleMax;
   flow_params[4].type = TYPE_INT;    flow_params[4].integer_value = Flow_InpMFIPeriod;
   flow_params[5].type = TYPE_BOOL;   flow_params[5].integer_value = Flow_InpShowVROC;
   flow_params[6].type = TYPE_INT;    flow_params[6].integer_value = Flow_InpVROCPeriod;
   flow_params[7].type = TYPE_DOUBLE; flow_params[7].double_value = Flow_InpVROCThreshold;
   flow_params[8].type = TYPE_BOOL;   flow_params[8].integer_value = Flow_InpUseApproxDelta;
   flow_params[9].type = TYPE_INT;    flow_params[9].integer_value = Flow_InpDeltaSmooth;
   flow_params[10].type = TYPE_INT;   flow_params[10].integer_value = Flow_InpNormalizationLen;
   flow_params[11].type = TYPE_DOUBLE; flow_params[11].double_value = Flow_InpDeltaScaleFactor;
   flow_params[12].type = TYPE_DOUBLE; flow_params[12].double_value = Flow_InpHistogramVisualGain;

   h_flow = IndicatorCreate(_Symbol, _Period, IND_CUSTOM, 13, flow_params);
   if(h_flow != INVALID_HANDLE) ChartIndicatorAdd(0, 2, h_flow);

   // 3. Momentum (Subwindow 3)
   MqlParam mom_params[15];
   mom_params[0].type = TYPE_STRING; mom_params[0].string_value = path_mom;
   mom_params[1].type = TYPE_INT;    mom_params[1].integer_value = Mom_InpColorLogic;
   mom_params[2].type = TYPE_INT;    mom_params[2].integer_value = Mom_InpFastPeriod;
   mom_params[3].type = TYPE_INT;    mom_params[3].integer_value = Mom_InpSlowPeriod;
   mom_params[4].type = TYPE_INT;    mom_params[4].integer_value = Mom_InpSignalPeriod;
   mom_params[5].type = TYPE_INT;    mom_params[5].integer_value = Mom_InpAppliedPrice;
   mom_params[6].type = TYPE_DOUBLE; mom_params[6].double_value = Mom_InpKalmanGain;
   mom_params[7].type = TYPE_DOUBLE; mom_params[7].double_value = Mom_InpPhaseAdvance;
   mom_params[8].type = TYPE_BOOL;   mom_params[8].integer_value = Mom_InpEnableBoost;
   mom_params[9].type = TYPE_DOUBLE; mom_params[9].double_value = Mom_InpStochMixWeight;
   mom_params[10].type = TYPE_INT;   mom_params[10].integer_value = Mom_InpStochK;
   mom_params[11].type = TYPE_INT;   mom_params[11].integer_value = Mom_InpStochD;
   mom_params[12].type = TYPE_INT;   mom_params[12].integer_value = Mom_InpStochSlowing;
   mom_params[13].type = TYPE_INT;   mom_params[13].integer_value = Mom_InpNormPeriod;
   mom_params[14].type = TYPE_DOUBLE;mom_params[14].double_value = Mom_InpNormSensitivity;

   h_momentum = IndicatorCreate(_Symbol, _Period, IND_CUSTOM, 15, mom_params);
   if(h_momentum != INVALID_HANDLE) ChartIndicatorAdd(0, 3, h_momentum);


   // Init Log
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(time_str, ":", "");
   StringReplace(time_str, " ", "_");
   StringReplace(time_str, ".", "");
   string filename = "Mimic_Research_" + _Symbol + "_" + time_str + ".csv";

   ResetLastError();
   g_log_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

   if(g_log_handle != INVALID_HANDLE)
     {
      // Updated Header for v2.14: Added Account Info, LotDir, Currency, SLTP, Verdict
      string header = "Time,TickMS,Phase,MimicMode,TargetTP,Bid,Ask,Spread,Velocity,Acceleration,Hybrid_MACD,Hybrid_Color,Hybrid_DFCurve,Flow_MFI,Flow_DUp,Flow_DDown,Mom_Hist,Pivot_PP,Pivot_R1,Pivot_S1,Floating_PL,Realized_PL,Session_PL,Balance,Margin,MarginPercent,Currency,LotDir,Action,PosCount,ActiveSL,ActiveTP,SLTP_Levels,Verdict,LastEvent,DOM_Snapshot\r\n";
      FileWriteString(g_log_handle, header);
      FileFlush(g_log_handle);
      Print("Mimic Research v2.14: Log file created: ", filename);
     }

   CreatePanel();
   UpdateUI();

   Print("Mimic Trap Research EA v2.14 (v2.11 Base + Enhanced Forensic CSV) Initialized.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DestroyPanel();
   CleanupChart();
   RemoveIndicators();

   if(g_book_subscribed) MarketBookRelease(_Symbol);

   if(h_hybrid != INVALID_HANDLE) IndicatorRelease(h_hybrid);
   if(h_momentum != INVALID_HANDLE) IndicatorRelease(h_momentum);
   if(h_flow != INVALID_HANDLE) IndicatorRelease(h_flow);

   if(g_log_handle != INVALID_HANDLE) FileClose(g_log_handle);
  }

void RemoveIndicators()
{
    int windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
    for (int w = windows - 1; w >= 0; w--)
    {
        int total = ChartIndicatorsTotal(0, w);
        for (int i = total - 1; i >= 0; i--)
        {
            string name = ChartIndicatorName(0, w, i);
            string name_lower = name;
            StringToLower(name_lower);

            // Clean up old and new names
            if (StringFind(name_lower, "hybrid momentum") >= 0 ||
                StringFind(name_lower, "hybrid flow") >= 0 ||
                StringFind(name_lower, "jules_hybrid") >= 0 ||
                StringFind(name_lower, "va(") >= 0 ||
                StringFind(name_lower, "microstructure") >= 0 ||
                StringFind(name_lower, "wvf") >= 0 ||
                StringFind(name_lower, "hybrid_") >= 0)
            {
                ChartIndicatorDelete(0, w, name);
            }
        }
    }
}

void CleanupChart()
  {
   ObjectsDeleteAll(0, Prefix);
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
      // --- MIMIC TOGGLE ---
      if(sparam == ObjBtnMimicToggle) {
          g_mimic_mode = !g_mimic_mode;
          PlaySound("click.wav");
          UpdateUI();
          ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // --- TRAP BUY ---
      else if(sparam == ObjBtnTrapBuy)
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         ChartRedraw();
         Sleep(100);
         PlaySound("tick.wav");
         ArmTrap(ORDER_TYPE_BUY);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
        }
      // --- TRAP SELL ---
      else if(sparam == ObjBtnTrapSell)
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         ChartRedraw();
         Sleep(100);
         PlaySound("tick.wav");
         ArmTrap(ORDER_TYPE_SELL);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
        }
      // --- TRAP BURST ---
      else if(sparam == ObjBtnTrapBurst)
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         ChartRedraw();
         Sleep(100);
         PlaySound("tick.wav");
         ExecuteBurstTrap();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
        }
      // --- CLOSE ALL ---
      else if(sparam == ObjBtnCloseAll)
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         ChartRedraw();
         Sleep(100);
         g_trap_active = false;
         g_current_phase = "IDLE";
         CloseAll();
         UpdateUI();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
        }
     }
   // --- EDIT END ---
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
       if(sparam == ObjEditTP) {
           string text = ObjectGetString(0, ObjEditTP, OBJPROP_TEXT);
           g_target_profit_eur = StringToDouble(text);
           Print("Mimic: Target Profit Updated to: ", g_target_profit_eur);
       }
       else if(sparam == ObjEditLot) {
           string text = ObjectGetString(0, ObjEditLot, OBJPROP_TEXT);
           double val = StringToDouble(text);
           if(val > 0) g_user_lot_size = val;
           Print("Mimic: Lot Size Updated to: ", g_user_lot_size);
       }
       else if(sparam == ObjEditBCount) {
           string text = ObjectGetString(0, ObjEditBCount, OBJPROP_TEXT);
           long val = StringToInteger(text);
           if(val > 0) g_user_burst_count = (int)val;
           Print("Mimic: Burst Count Updated to: ", g_user_burst_count);
       }
       else if(sparam == ObjEditBDelay) {
           string text = ObjectGetString(0, ObjEditBDelay, OBJPROP_TEXT);
           long val = StringToInteger(text);
           if(val >= 0) g_user_burst_delay = (int)val;
           Print("Mimic: Burst Delay Updated to: ", g_user_burst_delay);
       }
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

   // --- TARGET PROFIT CHECK ---
   double current_float = GetFloatingPL();
   if(g_target_profit_eur > 0.0 && current_float >= g_target_profit_eur) {
       Print("Mimic: Target Profit Hit (", current_float, " >= ", g_target_profit_eur, "). Closing All.");
       PlaySound("coins.wav");
       CloseAll();
       g_trap_active = false;
       g_current_phase = "IDLE";
       g_tick_event_buffer += "TP_HIT;";
       UpdateUI();
   }

   // --- STATE MACHINE UPDATE ---
   if (g_trap_active) {
       // Armed state managed by ArmTrap
   }
   else if (PositionsTotal() > 0) {
       g_current_phase = "ACTIVE_HOLD";
   }
   else if (g_current_phase != "POST_ANALYSIS") {
       g_current_phase = "IDLE";
   }

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
       if (bid != g_last_price) {
           g_post_event_counter--;
           if (g_post_event_counter <= 0) {
               g_current_phase = "IDLE";
               Print("Mimic: Post-Event Analysis Complete.");
           }
       }
   }

   // --- LOGGING ---
   WriteLog();

   // Reset "One-Shot" variables
   g_last_realized_pl = 0.0;
   g_last_price = bid;
   g_tick_event_buffer = ""; // Clear events
  }

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      DrawDealVisuals(trans.deal);

      long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
          double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
          double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
          double comm = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
          double total_deal = profit + swap + comm;
          g_last_realized_pl += total_deal;
          g_session_realized_pl += total_deal;

          // --- DETECT DECOY vs TROJAN ---
          string comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
          string magic_s = IntegerToString(HistoryDealGetInteger(trans.deal, DEAL_MAGIC));

          if (StringFind(comment, "Decoy") >= 0) {
              g_tick_event_buffer += "CLOSE_DECOY_" + DoubleToString(total_deal, 2) + ";";
          } else if (StringFind(comment, "Trojan") >= 0) {
              g_tick_event_buffer += "CLOSE_TROJAN_" + DoubleToString(total_deal, 2) + ";";
          } else {
              g_tick_event_buffer += "CLOSE_MANUAL_" + DoubleToString(total_deal, 2) + ";";
          }

          UpdateUI(); // Update Banked P/L
      }
     }
  }

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
   g_tick_event_buffer += "TRAP_FIRED;";

   // Calculate SL/TP based on 5% rule
   double sl=0, tp=0;

   if (g_mimic_mode)
   {
       // 1. DECOY PHASE (Opposite Direction) - ONLY IN MIMIC MODE
       ENUM_ORDER_TYPE decoy_dir = (g_trap_direction == ORDER_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
       double d_lot = NormalizeLot(InpDecoyLot);

       for(int i=0; i<InpDecoyCount; i++) {
          CalculateSLTP(decoy_dir, (decoy_dir==ORDER_TYPE_BUY)?m_symbol.Ask():m_symbol.Bid(), sl, tp);
          if(m_trade.PositionOpen(_Symbol, decoy_dir, d_lot, (decoy_dir==ORDER_TYPE_BUY)?m_symbol.Ask():m_symbol.Bid(), sl, tp, InpComment+"_Decoy")) {
             Sleep(20); // Minimal spacing
          }
       }
   }
   else
   {
       Print("Mimic: DIRECT MODE - Skipping Decoys.");
   }

   // 2. TROJAN PHASE (Real Direction)
   double t_lot = NormalizeLot(g_user_lot_size);
   CalculateSLTP(g_trap_direction, (g_trap_direction==ORDER_TYPE_BUY)?m_symbol.Ask():m_symbol.Bid(), sl, tp);

   if(m_trade.PositionOpen(_Symbol, g_trap_direction, t_lot, (g_trap_direction==ORDER_TYPE_BUY)?m_symbol.Ask():m_symbol.Bid(), sl, tp, InpComment+"_Trojan")) {
       // Done
   }

   PlaySound("ok.wav");
   Print("Mimic: TRAP EXECUTED!");

   // Set Post-Event Phase
   g_current_phase = "POST_ANALYSIS";
   g_post_event_counter = InpPostEventTicks;

   UpdateUI();
  }

void ExecuteBurstTrap()
{
   g_trap_active = false; // Ensure no pending traps
   g_current_phase = "BURST_EXEC";
   g_tick_event_buffer += "BURST_FIRED;";

   Print("Mimic: EXECUTING BURST TRAP (Count: ", g_user_burst_count, ", Delay: ", g_user_burst_delay, ")");

   double t_lot = NormalizeLot(g_user_lot_size);
   double sl=0, tp=0;

   for (int i = 0; i < g_user_burst_count; i++)
   {
       m_symbol.RefreshRates();

       // Open BUY
       CalculateSLTP(ORDER_TYPE_BUY, m_symbol.Ask(), sl, tp);
       if(m_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, t_lot, m_symbol.Ask(), sl, tp, InpComment+"_Burst")) {
           // OK
       }

       // Open SELL
       CalculateSLTP(ORDER_TYPE_SELL, m_symbol.Bid(), sl, tp);
       if(m_trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, t_lot, m_symbol.Bid(), sl, tp, InpComment+"_Burst")) {
           // OK
       }

       // Delay between waves
       if (i < g_user_burst_count - 1 && g_user_burst_delay > 0)
           Sleep(g_user_burst_delay);
   }

   PlaySound("ok.wav");

   // Set Post-Event Phase
   g_current_phase = "POST_ANALYSIS";
   g_post_event_counter = InpPostEventTicks;

   UpdateUI();
}

void CloseAll()
  {
   g_tick_event_buffer += "CLOSE_ALL_TRIG;";
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber) {
         m_trade.PositionClose(m_position.Ticket());
      }
   }
   Print("Mimic: All positions closed.");
  }

void CalculateSLTP(ENUM_ORDER_TYPE type, double price, double &sl, double &tp)
{
    if (InpSLPercent <= 0 && InpTPPercent <= 0) {
        sl = 0; tp = 0; return;
    }

    double delta_sl = price * (InpSLPercent / 100.0);
    double delta_tp = price * (InpTPPercent / 100.0);

    if (type == ORDER_TYPE_BUY) {
        sl = (InpSLPercent > 0) ? price - delta_sl : 0;
        tp = (InpTPPercent > 0) ? price + delta_tp : 0;
    } else {
        sl = (InpSLPercent > 0) ? price + delta_sl : 0;
        tp = (InpTPPercent > 0) ? price - delta_tp : 0;
    }

    // Normalize
    double tick_size = m_symbol.TickSize();
    if(sl>0) sl = MathRound(sl/tick_size)*tick_size;
    if(tp>0) tp = MathRound(tp/tick_size)*tick_size;
}

//+------------------------------------------------------------------+
//| GUI                                                              |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x = InpX;
   int y = InpY;
   int w = 150; 
   int h = 280;

   int btn_w = 130; 
   int btn_h = 24;  
   int gap_y = 26;  

   // Background
   ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   int curr_y = y + 5;

   // Status Label
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, InpTxtColor);
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "READY v2.14");
   curr_y += 20;

   // Row: Mimic Toggle
   ObjectCreate(0, ObjBtnMimicToggle, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnMimicToggle, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnMimicToggle, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjBtnMimicToggle, OBJPROP_XSIZE, btn_w);
   ObjectSetInteger(0, ObjBtnMimicToggle, OBJPROP_YSIZE, 20);
   ObjectSetString(0, ObjBtnMimicToggle, OBJPROP_TEXT, "MIMIC MODE: ON");
   ObjectSetInteger(0, ObjBtnMimicToggle, OBJPROP_BGCOLOR, clrForestGreen);
   ObjectSetInteger(0, ObjBtnMimicToggle, OBJPROP_COLOR, clrWhite);
   curr_y += 25;

   // Input: Lot Size
   ObjectCreate(0, ObjLabelLot, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_COLOR, InpTxtColor);
   ObjectSetString(0, ObjLabelLot, OBJPROP_TEXT, "Lot:");

   ObjectCreate(0, ObjEditLot, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XDISTANCE, x+40);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XSIZE, 50);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditLot, OBJPROP_TEXT, DoubleToString(g_user_lot_size, 2));
   ObjectSetInteger(0, ObjEditLot, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_COLOR, clrBlack);
   curr_y += 20;

   // Input: Burst Count & Delay
   ObjectCreate(0, ObjLabelBCount, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelBCount, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelBCount, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjLabelBCount, OBJPROP_COLOR, InpTxtColor);
   ObjectSetString(0, ObjLabelBCount, OBJPROP_TEXT, "Cnt/Ms:");

   ObjectCreate(0, ObjEditBCount, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditBCount, OBJPROP_XDISTANCE, x+60);
   ObjectSetInteger(0, ObjEditBCount, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjEditBCount, OBJPROP_XSIZE, 30);
   ObjectSetInteger(0, ObjEditBCount, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditBCount, OBJPROP_TEXT, IntegerToString(g_user_burst_count));
   ObjectSetInteger(0, ObjEditBCount, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, ObjEditBCount, OBJPROP_COLOR, clrBlack);

   ObjectCreate(0, ObjEditBDelay, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditBDelay, OBJPROP_XDISTANCE, x+95);
   ObjectSetInteger(0, ObjEditBDelay, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjEditBDelay, OBJPROP_XSIZE, 40);
   ObjectSetInteger(0, ObjEditBDelay, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditBDelay, OBJPROP_TEXT, IntegerToString(g_user_burst_delay));
   ObjectSetInteger(0, ObjEditBDelay, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, ObjEditBDelay, OBJPROP_COLOR, clrBlack);
   curr_y += 20;

   // Input: Target Profit
   ObjectCreate(0, ObjLabelTP, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelTP, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelTP, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjLabelTP, OBJPROP_COLOR, InpTxtColor);
   ObjectSetString(0, ObjLabelTP, OBJPROP_TEXT, "TP EUR:");

   ObjectCreate(0, ObjEditTP, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditTP, OBJPROP_XDISTANCE, x+70);
   ObjectSetInteger(0, ObjEditTP, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjEditTP, OBJPROP_XSIZE, 65);
   ObjectSetInteger(0, ObjEditTP, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditTP, OBJPROP_TEXT, "0.0");
   ObjectSetInteger(0, ObjEditTP, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, ObjEditTP, OBJPROP_COLOR, clrBlack);
   curr_y += 25;

   // P/L Display
   ObjectCreate(0, ObjLabelPL, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, "FL: 0.0 | BK: 0.0");
   curr_y += 20;

   // TRAP BUY
   ObjectCreate(0, ObjBtnTrapBuy, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_XSIZE, btn_w);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_YSIZE, btn_h);
   ObjectSetString(0, ObjBtnTrapBuy, OBJPROP_TEXT, "TRAP BUY");
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_BGCOLOR, clrForestGreen);
   ObjectSetInteger(0, ObjBtnTrapBuy, OBJPROP_COLOR, clrWhite);
   curr_y += gap_y;

   // TRAP SELL
   ObjectCreate(0, ObjBtnTrapSell, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_XSIZE, btn_w);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_YSIZE, btn_h);
   ObjectSetString(0, ObjBtnTrapSell, OBJPROP_TEXT, "TRAP SELL");
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_BGCOLOR, clrFireBrick);
   ObjectSetInteger(0, ObjBtnTrapSell, OBJPROP_COLOR, clrWhite);
   curr_y += gap_y;

   // TRAP BURST
   ObjectCreate(0, ObjBtnTrapBurst, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnTrapBurst, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnTrapBurst, OBJPROP_YDISTANCE, curr_y);
   ObjectSetInteger(0, ObjBtnTrapBurst, OBJPROP_XSIZE, btn_w);
   ObjectSetInteger(0, ObjBtnTrapBurst, OBJPROP_YSIZE, btn_h);
   ObjectSetString(0, ObjBtnTrapBurst, OBJPROP_TEXT, "BURST (DUAL)");
   ObjectSetInteger(0, ObjBtnTrapBurst, OBJPROP_BGCOLOR, clrRoyalBlue);
   ObjectSetInteger(0, ObjBtnTrapBurst, OBJPROP_COLOR, clrWhite);
   curr_y += gap_y;

   // CLOSE ALL
   ObjectCreate(0, ObjBtnCloseAll, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_YDISTANCE, curr_y + 5);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_XSIZE, btn_w);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjBtnCloseAll, OBJPROP_TEXT, "CLOSE ALL");
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_BGCOLOR, clrDimGray);
   ObjectSetInteger(0, ObjBtnCloseAll, OBJPROP_COLOR, clrWhite);
  }

void UpdateUI()
  {
   // Status
   string status_text = g_current_phase;
   if(g_trap_active) {
       string dir = (g_trap_direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
       status_text = "ARMED: " + dir + " (" + IntegerToString(g_trap_counter_ticks) + "/" + IntegerToString(InpTriggerTicks) + ")";
   }
   else if (g_current_phase == "POST_ANALYSIS") {
       status_text = "LOGGING: " + IntegerToString(g_post_event_counter);
   }
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, status_text);

   // Mimic Button
   ObjectSetString(0, ObjBtnMimicToggle, OBJPROP_TEXT, g_mimic_mode ? "MIMIC MODE: ON" : "DIRECT MODE");
   ObjectSetInteger(0, ObjBtnMimicToggle, OBJPROP_BGCOLOR, g_mimic_mode ? clrForestGreen : clrDimGray);

   // P/L Label
   double fl = GetFloatingPL();
   string pl_str = StringFormat("FL: %.2f | BK: %.2f", fl, g_session_realized_pl);
   ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, pl_str);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, (fl >= 0) ? clrLime : clrRed);

   // Trap Buttons
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

void WriteLog()
  {
   if(g_log_handle == INVALID_HANDLE) return;

   // 1. Get Indicator Values
   double mom_hist = 0;
   double flow_mfi = 0, flow_dup = 0, flow_ddown = 0;
   double hybrid_macd = 0, hybrid_color = 0, hybrid_curve = 0;

   double buf[1];

   // A. Jules Hybrid v1.04
   if(CopyBuffer(h_hybrid, 0, 0, 1, buf)>0) hybrid_macd = buf[0];
   if(CopyBuffer(h_hybrid, 1, 0, 1, buf)>0) hybrid_color = buf[0];
   if(CopyBuffer(h_hybrid, 2, 0, 1, buf)>0) hybrid_curve = buf[0];

   // B. Flow
   if(CopyBuffer(h_flow, 0, 0, 1, buf)>0) flow_mfi = buf[0];
   double up_end=50, down_end=50;
   if(CopyBuffer(h_flow, 3, 0, 1, buf)>0) up_end = buf[0];
   if(CopyBuffer(h_flow, 5, 0, 1, buf)>0) down_end = buf[0];
   flow_dup = up_end - 50.0;
   flow_ddown = down_end - 50.0;

   // C. Momentum (Legacy)
   if(CopyBuffer(h_momentum, 0, 0, 1, buf)>0) mom_hist = buf[0];

   // 2. Physics
   PhysicsState p = m_physics.GetState();

   // 3. Pivots
   double pp=0, r1=0, s1=0;
   CalcDailyPivots(pp, r1, s1);

   // 4. P/L & Positions
   double float_pl = 0.0;
   int pos_count = 0;
   double active_sl = 0.0;
   double active_tp = 0.0;

   for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber) {
           float_pl += m_position.Profit() + m_position.Swap() + m_position.Commission();
           pos_count++;
           if(m_position.StopLoss() > 0) active_sl = m_position.StopLoss();
           if(m_position.TakeProfit() > 0) active_tp = m_position.TakeProfit();
       }
   }

   // 5. Account Info (NEW)
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   string lot_dir = GetNetLotDirection();
   string sltp_levels = GetSLTPSnapshot();
   string verdict = DetermineVerdict(p.velocity, float_pl);


   // 6. Time
   string t = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string ms = IntegerToString(GetTickCount()%1000);

   // CSV Row
   // Header: Time,TickMS,Phase,MimicMode,TargetTP,Bid,Ask,Spread,Velocity,Acceleration,Hybrid_MACD,Hybrid_Color,Hybrid_DFCurve,Flow_MFI,Flow_DUp,Flow_DDown,Mom_Hist,Pivot_PP,Pivot_R1,Pivot_S1,Floating_PL,Realized_PL,Session_PL,Balance,Margin,MarginPercent,Currency,LotDir,Action,PosCount,ActiveSL,ActiveTP,SLTP_Levels,Verdict,LastEvent,DOM_Snapshot
   string row = StringFormat("%s,%s,%s,%d,%.2f,%.5f,%.5f,%.1f,%.5f,%.5f,%.5f,%.0f,%.5f,%.2f,%.2f,%.2f,%.5f,%.5f,%.5f,%.5f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%s,%s,%s,%d,%.5f,%.5f,%s,%s,%s",
       t, ms, g_current_phase,
       g_mimic_mode, g_target_profit_eur,
       m_symbol.Bid(), m_symbol.Ask(), p.spread_avg,
       p.velocity, p.acceleration,
       hybrid_macd, hybrid_color, hybrid_curve,
       flow_mfi, flow_dup, flow_ddown,
       mom_hist,
       pp, r1, s1,
       float_pl, g_last_realized_pl, g_session_realized_pl,
       balance, margin, margin_level, currency, lot_dir,
       InpComment,
       pos_count, active_sl, active_tp, sltp_levels, verdict,
       g_tick_event_buffer
   );

   string dom_part = GetDOMSnapshot();
   FileWriteString(g_log_handle, row + "," + dom_part + "\r\n");
   FileFlush(g_log_handle);
  }

void CalcDailyPivots(double &pp, double &r1, double &s1)
{
    // Use Daily (PERIOD_D1) data from previous bar (index 1)
    double high = iHigh(_Symbol, PERIOD_D1, 1);
    double low  = iLow(_Symbol, PERIOD_D1, 1);
    double close= iClose(_Symbol, PERIOD_D1, 1);

    if(high == 0 || low == 0 || close == 0) return;

    pp = (high + low + close) / 3.0;
    r1 = (2.0 * pp) - low;
    s1 = (2.0 * pp) - high;
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
   ObjectDelete(0, ObjBtnTrapBurst);
   ObjectDelete(0, ObjBtnCloseAll);
   ObjectDelete(0, ObjBtnMimicToggle);
   ObjectDelete(0, ObjEditTP);
   ObjectDelete(0, ObjLabelTP);
   ObjectDelete(0, ObjEditLot);
   ObjectDelete(0, ObjLabelLot);
   ObjectDelete(0, ObjEditBCount);
   ObjectDelete(0, ObjLabelBCount);
   ObjectDelete(0, ObjEditBDelay);
   ObjectDelete(0, ObjLabelBDelay);
   ObjectDelete(0, ObjLabelPL);
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

// --- v2.14 Forensic Helpers ---
string GetNetLotDirection()
{
    double net_lots = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber) {
           if(m_position.PositionType() == POSITION_TYPE_BUY) net_lots += m_position.Volume();
           else net_lots -= m_position.Volume();
       }
    }
    if(net_lots > 0.001) return "BUY";
    if(net_lots < -0.001) return "SELL";
    if(PositionsTotal() > 0) return "NEUTRAL_HEDGE";
    return "NONE";
}

string GetSLTPSnapshot()
{
    string s = "";
    int count = 0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagicNumber) {
           if(count > 0) s += "|";
           string type = (m_position.PositionType() == POSITION_TYPE_BUY) ? "B" : "S";
           s += type + ":" + DoubleToString(m_position.StopLoss(), _Digits) + "/" + DoubleToString(m_position.TakeProfit(), _Digits);
           count++;
           if(count >= 3) { s += "|..."; break; } // Limit length
       }
    }
    if(s == "") return "NONE";
    return s;
}

string DetermineVerdict(double velocity, double pl)
{
    if(pl < -50.0 && velocity > 20.0) return "CRASH_RISK";
    if(pl > 10.0) return "WINNING";
    if(pl < -10.0) return "UNDER_PRESSURE";
    return "STABLE";
}
