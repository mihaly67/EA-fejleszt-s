//+------------------------------------------------------------------+
//|                                  Mimic_BarbedWire_Probe_EA.mq5   |
//|                                                      Jules Agent |
//|                       Focused Strategy: Barbed Wire (Szögesdrót) |
//|                       Mode: PROBE & STRESS TEST (v1.0)           |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "1.00"
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
enum ENUM_COLOR_LOGIC {
    COLOR_SLOPE,     // Slope (Change from Prev Bar) - FASTEST
    COLOR_CROSSOVER, // MACD > Signal (Classic) - LAGGING
    COLOR_ZERO_CROSS // MACD > 0 (Simple)
};

//--- Inputs
// [Strategy Settings]
input double        InpSpreadMult        = 1.0;       // [Strategy] Barbed Wire Spread Multiplier
input string        InpIndPath           = "Jules\\"; // [Strategy] Indicator Path

// [Position Size]
input double        InpLotSize           = 0.01;      // [Position] Lot Size (Editable on Panel)

// [Risk Management]
input int           InpSlippage          = 10;     // [Risk] Slippage
input ulong         InpMagicNumber       = 999003; // [Risk] Magic Number (Distinct)
input string        InpComment           = "MimicWire"; // [Risk] Comment

// [Jules Hybrid Momentum Pulse v1.04 Settings]
input uint           Hybrid_InpPeriodFastEMA     =  3;
input uint           Hybrid_InpPeriodSlowEMA     =  6;
input uint           Hybrid_InpPeriodBB          =  20;
input double         Hybrid_InpDeviationBB       =  2.0;
input ENUM_MA_METHOD Hybrid_InpMethodBB          =  MODE_EMA;
input uint           Hybrid_InpPeriodKeltner     =  20;
input double         Hybrid_InpDeviationKeltner  =  1.5;
input uint           Hybrid_InpPeriodATRKeltner  =  10;
input ENUM_MA_METHOD Hybrid_InpMethodKeltner     =  MODE_EMA;
input double         Hybrid_InpMACDScale         =  4.0;
input int            Hybrid_InpDFShift           = 0;
input double         Hybrid_InpDFScale           = 1.0;
input bool           Hybrid_InpUseAutoScaling    = true;
input int            Hybrid_InpAutoScaleLookback = 100;

// [Momentum Settings (Legacy)]
input ENUM_COLOR_LOGIC   Mom_InpColorLogic     = COLOR_SLOPE;
input int                Mom_InpFastPeriod     = 3;
input int                Mom_InpSlowPeriod     = 6;
input int                Mom_InpSignalPeriod   = 13;
input ENUM_APPLIED_PRICE Mom_InpAppliedPrice   = PRICE_CLOSE;
input double             Mom_InpKalmanGain     = 1.0;
input double             Mom_InpPhaseAdvance   = 0.5;
input bool               Mom_InpEnableBoost    = true;
input double             Mom_InpStochMixWeight = 0.2;
input int                Mom_InpStochK         = 5;
input int                Mom_InpStochD         = 3;
input int                Mom_InpStochSlowing   = 3;
input int                Mom_InpNormPeriod     = 100;
input double             Mom_InpNormSensitivity= 1.0;

// [Flow Settings]
input bool               Flow_InpUseFixedScale       = false;
input double             Flow_InpScaleMin            = -100.0;
input double             Flow_InpScaleMax            = 200.0;
input int                Flow_InpMFIPeriod           = 14;
input bool               Flow_InpShowVROC            = true;
input int                Flow_InpVROCPeriod          = 10;
input double             Flow_InpVROCThreshold       = 20.0;
input bool               Flow_InpUseApproxDelta      = true;
input int                Flow_InpDeltaSmooth         = 3;
input int                Flow_InpNormalizationLen    = 100;
input double             Flow_InpDeltaScaleFactor    = 50.0;
input double             Flow_InpHistogramVisualGain = 3.0;

// [Panel UI]
input int           InpX                 = 10;               // [UI] X Coordinate
input int           InpY                 = 20;               // [UI] Y Coordinate
input color         InpBgColor           = clrBlack;         // [UI] BG Color (Wire Theme)
input color         InpTxtColor          = clrWhite;         // [UI] Text Color

//--- Globals
bool              g_active = false;      // Is the strategy running?
int               g_log_handle = INVALID_HANDLE;
bool              g_book_subscribed = false;

// Research Globals (Indicators)
int               h_hybrid = INVALID_HANDLE;
int               h_momentum = INVALID_HANDLE;
int               h_flow = INVALID_HANDLE;

string            g_current_phase = "IDLE";
double            g_last_realized_pl = 0.0;
double            g_session_realized_pl = 0.0;
string            g_tick_event_buffer = "";

// User Controllable Globals
double            g_user_lot_size = InpLotSize;

// Wire Stats
int               g_wire_layers_count = 0;

//--- GUI Objects
string Prefix = "MimicWire_";
string ObjBG = Prefix + "BG";
string ObjStat = Prefix + "Status";
string ObjBtnToggle = Prefix + "BtnToggle";
string ObjEditLot = Prefix + "EditLot";
string ObjLabelLot = Prefix + "LabelLot";
string ObjLabelPL = Prefix + "LabelPL";
string ObjLabelLayers = Prefix + "LabelLayers";

//--- Forward Declarations
void CreatePanel();
void UpdateUI();
void DestroyPanel();
void CleanupChart();
void RemoveIndicators();
void DrawDealVisuals(ulong deal_ticket);
void StartBarbedWire();
void ExpandBarbedWire(double center_price);
double NormalizeLot(double lot);
void WriteLog();
double GetFloatingPL();
void CalcDailyPivots(double &pp, double &r1, double &s1);

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Cleanup
   RemoveIndicators();
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);
   CleanupChart();

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetDeviationInPoints(InpSlippage);

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.RefreshRates();

   if(MarketBookAdd(_Symbol)) g_book_subscribed = true;

   g_user_lot_size = InpLotSize;

   // --- INDICATOR HANDLES ---
   string path_hybrid = InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.04";
   string path_mom = InpIndPath + "HybridMomentumIndicator_v2.82";
   string path_flow = InpIndPath + "HybridFlowIndicator_v1.125";

   // 1. Jules Hybrid
   h_hybrid = iCustom(_Symbol, _Period, path_hybrid,
                      Hybrid_InpPeriodFastEMA, Hybrid_InpPeriodSlowEMA, Hybrid_InpPeriodBB, Hybrid_InpDeviationBB, Hybrid_InpMethodBB,
                      Hybrid_InpPeriodKeltner, Hybrid_InpDeviationKeltner, Hybrid_InpPeriodATRKeltner, Hybrid_InpMethodKeltner,
                      Hybrid_InpMACDScale, Hybrid_InpDFShift, Hybrid_InpDFScale, Hybrid_InpUseAutoScaling, Hybrid_InpAutoScaleLookback);
   if(h_hybrid != INVALID_HANDLE) ChartIndicatorAdd(0, 1, h_hybrid);

   // 2. Filter Flow
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

   // 3. Momentum
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

   // Init Log (v2.11 Format without DOM)
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(time_str, ":", ""); StringReplace(time_str, " ", "_");
   string filename = "Mimic_Probe_WIRE_" + _Symbol + "_" + time_str + ".csv";
   g_log_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(g_log_handle != INVALID_HANDLE) {
      // EXACT v2.11 Header minus DOM_Snapshot
      string header = "Time,TickMS,Phase,MimicMode,TargetTP,Bid,Ask,Spread,Velocity,Acceleration,Hybrid_MACD,Hybrid_Color,Hybrid_DFCurve,Flow_MFI,Flow_DUp,Flow_DDown,Mom_Hist,Pivot_PP,Pivot_R1,Pivot_S1,Floating_PL,Realized_PL,Session_PL,Action,PosCount,ActiveSL,ActiveTP,LastEvent\r\n";
      FileWriteString(g_log_handle, header);
      FileFlush(g_log_handle);
   }

   CreatePanel();
   UpdateUI();

   Print("Mimic Barbed Wire Probe EA v1.0 Initialized.");
   return(INIT_SUCCEEDED);
  }

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
    for (int w = windows - 1; w >= 0; w--) {
        int total = ChartIndicatorsTotal(0, w);
        for (int i = total - 1; i >= 0; i--) {
            string name = ChartIndicatorName(0, w, i);
            string nlow = name; StringToLower(nlow);
            if (StringFind(nlow, "hybrid") >= 0 || StringFind(nlow, "pulse") >= 0)
                ChartIndicatorDelete(0, w, name);
        }
    }
}

void CleanupChart()
  {
   ObjectsDeleteAll(0, Prefix);
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, "#") == 0 || ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_ARROW_BUY || ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_ARROW_SELL)
         ObjectDelete(0, name);
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
      if(sparam == ObjBtnToggle)
        {
         // Visual Feedback
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         ChartRedraw();
         Sleep(100);
         
         if(g_active) {
             // STOP
             g_active = false;
             g_current_phase = "STOPPED";
             Print("Mimic: WIRE STOPPED. No new layers will be created.");
         } else {
             // START
             g_active = true;
             StartBarbedWire();
         }
         
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
         UpdateUI();
        }
     }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
     {
      if(sparam == ObjEditLot) {
           string text = ObjectGetString(0, ObjEditLot, OBJPROP_TEXT);
           double val = StringToDouble(text);
           if(val > 0) g_user_lot_size = val;
           Print("Mimic: Lot Size Updated to: ", g_user_lot_size);
      }
     }
  }

//+------------------------------------------------------------------+
//| Main Tick Loop                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick)) m_physics.Update(tick);
   m_symbol.RefreshRates();

   WriteLog();
   
   // Reset Tick Events
   g_last_realized_pl = 0.0;
   g_tick_event_buffer = "";
  }

//+------------------------------------------------------------------+
//| Transaction Handling (The Wire Logic)                            |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      DrawDealVisuals(trans.deal);

      long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
          // Closed P/L
          double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
          double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
          double comm = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
          double total = profit + swap + comm;
          g_last_realized_pl += total;
          g_session_realized_pl += total;
          UpdateUI();
      }
      
      // --- WIRE EXPANSION LOGIC ---
      if (g_active && entry == DEAL_ENTRY_IN)
      {
          // A pending order was filled (or market order executed)
          string comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
          double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
          
          if (StringFind(comment, "Wire") >= 0 || StringFind(comment, "Breach") >= 0) {
              g_tick_event_buffer += "LAYER_FILLED;";
              ExpandBarbedWire(price);
          }
      }
     }
  }

//+------------------------------------------------------------------+
//| Strategy Logic                                                   |
//+------------------------------------------------------------------+
void StartBarbedWire()
  {
   g_wire_layers_count = 0;
   g_current_phase = "WIRE_ACTIVE";
   
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double lot = NormalizeLot(g_user_lot_size);
   
   // 1. Initial Breach (Market Orders)
   // No SL/TP as requested (Manual Exit)
   m_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lot, ask, 0, 0, InpComment+"_BreachBuy");
   m_trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lot, bid, 0, 0, InpComment+"_BreachSell");
   
   g_tick_event_buffer += "WIRE_START;";
   
   // 2. First Layer
   ExpandBarbedWire((ask+bid)/2.0); // Center expansion on current price
   
   Print("Mimic: Barbed Wire STARTED.");
  }

void ExpandBarbedWire(double center_price)
  {
   if(!g_active) return;
   
   g_wire_layers_count++;
   
   m_symbol.RefreshRates();
   double spread = m_symbol.Ask() - m_symbol.Bid();
   double dist = spread * InpSpreadMult;
   if (dist < m_symbol.Point() * 10) dist = m_symbol.Point() * 10; // Min distance safety
   
   double buy_limit_price = NormalizeDouble(center_price - dist, _Digits);
   double sell_limit_price = NormalizeDouble(center_price + dist, _Digits);
   double lot = NormalizeLot(g_user_lot_size);
   
   // Place Pair
   m_trade.BuyLimit(lot, buy_limit_price, _Symbol, 0, 0, 0, 0, InpComment+"_Wire_L"+IntegerToString(g_wire_layers_count));
   m_trade.SellLimit(lot, sell_limit_price, _Symbol, 0, 0, 0, 0, InpComment+"_Wire_L"+IntegerToString(g_wire_layers_count));
   
   g_tick_event_buffer += "EXPAND_L" + IntegerToString(g_wire_layers_count) + ";";
   UpdateUI();
  }

//+------------------------------------------------------------------+
//| Logging & Utils                                                  |
//+------------------------------------------------------------------+
void WriteLog()
  {
   if(g_log_handle == INVALID_HANDLE) return;

   // 1. Indicators
   double buf[1];
   double hybrid_macd=0, hybrid_color=0, hybrid_curve=0;
   double flow_mfi=0, flow_dup=0, flow_ddown=0;
   double mom_hist=0;

   // Hybrid
   if(CopyBuffer(h_hybrid, 0, 0, 1, buf)>0) hybrid_macd = buf[0];
   if(CopyBuffer(h_hybrid, 1, 0, 1, buf)>0) hybrid_color = buf[0];
   if(CopyBuffer(h_hybrid, 2, 0, 1, buf)>0) hybrid_curve = buf[0];

   // Flow
   if(CopyBuffer(h_flow, 0, 0, 1, buf)>0) flow_mfi = buf[0];
   double u=50, d=50;
   if(CopyBuffer(h_flow, 3, 0, 1, buf)>0) u = buf[0];
   if(CopyBuffer(h_flow, 5, 0, 1, buf)>0) d = buf[0];
   flow_dup = u - 50.0; flow_ddown = d - 50.0;

   // Momentum
   if(CopyBuffer(h_momentum, 0, 0, 1, buf)>0) mom_hist = buf[0];

   // 2. Physics & Data
   PhysicsState p = m_physics.GetState();
   double pp=0, r1=0, s1=0;
   CalcDailyPivots(pp, r1, s1);

   double float_pl = GetFloatingPL();
   int pos_count = PositionsTotal();
   
   // Form CSV Row (No DOM)
   string row = StringFormat("%s,%s,%s,%d,%.2f,%.5f,%.5f,%.1f,%.5f,%.5f,%.5f,%.0f,%.5f,%.2f,%.2f,%.2f,%.5f,%.5f,%.5f,%.5f,%.2f,%.2f,%.2f,%s,%d,%.5f,%.5f,%s",
       TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), 
       IntegerToString(GetTickCount()%1000), 
       g_current_phase,
       0, 0.0, // MimicMode=0 (Probe), TargetTP=0
       m_symbol.Bid(), m_symbol.Ask(), p.spread_avg,
       p.velocity, p.acceleration,
       hybrid_macd, hybrid_color, hybrid_curve,
       flow_mfi, flow_dup, flow_ddown,
       mom_hist,
       pp, r1, s1,
       float_pl, g_last_realized_pl, g_session_realized_pl,
       InpComment,
       pos_count, 0.0, 0.0, // ActiveSL/TP = 0
       g_tick_event_buffer
   );

   FileWriteString(g_log_handle, row + "\r\n");
   FileFlush(g_log_handle);
  }

void CalcDailyPivots(double &pp, double &r1, double &s1) {
    double h = iHigh(_Symbol, PERIOD_D1, 1);
    double l  = iLow(_Symbol, PERIOD_D1, 1);
    double c= iClose(_Symbol, PERIOD_D1, 1);
    if(h==0) return;
    pp = (h+l+c)/3.0; r1=(2*pp)-l; s1=(2*pp)-h;
}

double GetFloatingPL() {
    double pl = 0.0;
    for(int i=PositionsTotal()-1; i>=0; i--) {
       if(m_position.SelectByIndex(i) && m_position.Magic()==InpMagicNumber)
           pl += m_position.Profit() + m_position.Swap() + m_position.Commission();
    }
    return pl;
}

double NormalizeLot(double lot) {
   double step = m_symbol.LotsStep();
   double min = m_symbol.LotsMin();
   double max = m_symbol.LotsMax();
   if(step > 0) lot = MathFloor(lot / step) * step;
   if(lot < min) lot = min;
   if(lot > max) lot = max;
   return lot;
}

void DrawDealVisuals(ulong deal_ticket) {
   if(!HistoryDealSelect(deal_ticket)) return;
   long entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   long type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   double price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   long time = HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   string name = Prefix + "Arrow_" + (string)deal_ticket;

   if(entry == DEAL_ENTRY_IN) {
      ENUM_OBJECT obj_type = (type == DEAL_TYPE_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      ObjectCreate(0, name, obj_type, 0, (datetime)time, price);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| GUI                                                              |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x = InpX, y = InpY, w = 140, h = 180;
   
   ObjectCreate(0, ObjBG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjBG, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, ObjBG, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, ObjBG, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, ObjBG, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, ObjBG, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, ObjBG, OBJPROP_BORDER_TYPE, BORDER_FLAT);

   int cy = y + 10;
   
   // Status
   ObjectCreate(0, ObjStat, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjStat, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjStat, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjStat, OBJPROP_COLOR, clrLime);
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "READY");
   cy += 25;
   
   // Lot Input
   ObjectCreate(0, ObjLabelLot, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjLabelLot, OBJPROP_COLOR, InpTxtColor);
   ObjectSetString(0, ObjLabelLot, OBJPROP_TEXT, "Lot:");
   
   ObjectCreate(0, ObjEditLot, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XDISTANCE, x+40);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_XSIZE, 50);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_YSIZE, 18);
   ObjectSetString(0, ObjEditLot, OBJPROP_TEXT, DoubleToString(g_user_lot_size, 2));
   ObjectSetInteger(0, ObjEditLot, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, ObjEditLot, OBJPROP_COLOR, clrBlack);
   cy += 30;
   
   // Start/Stop Button
   ObjectCreate(0, ObjBtnToggle, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnToggle, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnToggle, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjBtnToggle, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ObjBtnToggle, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ObjBtnToggle, OBJPROP_TEXT, "START WIRE");
   ObjectSetInteger(0, ObjBtnToggle, OBJPROP_BGCOLOR, clrGreen);
   ObjectSetInteger(0, ObjBtnToggle, OBJPROP_COLOR, clrWhite);
   cy += 40;
   
   // Info
   ObjectCreate(0, ObjLabelLayers, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelLayers, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelLayers, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjLabelLayers, OBJPROP_COLOR, clrYellow);
   cy += 20;
   
   ObjectCreate(0, ObjLabelPL, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrWhite);
  }

void UpdateUI()
  {
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, g_current_phase);
   
   if(g_active) {
       ObjectSetString(0, ObjBtnToggle, OBJPROP_TEXT, "STOP WIRE");
       ObjectSetInteger(0, ObjBtnToggle, OBJPROP_BGCOLOR, clrRed);
   } else {
       ObjectSetString(0, ObjBtnToggle, OBJPROP_TEXT, "START WIRE");
       ObjectSetInteger(0, ObjBtnToggle, OBJPROP_BGCOLOR, clrGreen);
   }
   
   ObjectSetString(0, ObjLabelLayers, OBJPROP_TEXT, "Layers: " + IntegerToString(g_wire_layers_count));
   ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, "PL: " + DoubleToString(GetFloatingPL(), 2));
   
   ChartRedraw();
  }

void DestroyPanel()
  {
   ObjectDelete(0, ObjBG); ObjectDelete(0, ObjStat);
   ObjectDelete(0, ObjBtnToggle); ObjectDelete(0, ObjEditLot);
   ObjectDelete(0, ObjLabelLot); ObjectDelete(0, ObjLabelLayers);
   ObjectDelete(0, ObjLabelPL);
  }
