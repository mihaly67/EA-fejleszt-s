//+------------------------------------------------------------------+
//|                                  Mimic_BarbedWire_Probe_EA_v1.02 |
//|                                                      Jules Agent |
//|                       Focused Strategy: Barbed Wire (Szögesdrót) |
//|                       Mode: MANUAL BURST FIRE (Grid Trap)        |
//+------------------------------------------------------------------+
#property copyright "Jules Agent & User"
#property link      "https://www.mql5.com"
#property version   "1.02"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include "../Include/Mimic/FireControl.mqh"
#include "../Indicators/PhysicsEngine.mqh"

//--- Objects
CTrade        m_trade;
CSymbolInfo   m_symbol;
CPositionInfo m_position;
PhysicsEngine m_physics(50);
CFireControl  m_fire_control;

//--- Enums
enum ENUM_COLOR_LOGIC {
    COLOR_SLOPE,     // Slope (Change from Prev Bar) - FASTEST
    COLOR_CROSSOVER, // MACD > Signal (Classic) - LAGGING
    COLOR_ZERO_CROSS // MACD > 0 (Simple)
};

//--- Inputs
// [Strategy Settings]
input double        InpSpreadMultStart   = 1.5;       // [Grid] Start Spread Multiplier
input double        InpSpreadMultStep    = 1.0;       // [Grid] Step Spread Multiplier per Layer
input int           InpLayers            = 3;         // [Grid] Number of Layers (Burst Size)
input double        InpSafeZonePts       = 50.0;      // [Safety] Minimum Distance (Points)
input string        InpIndPath           = "Jules\\"; // [Strategy] Indicator Path

// [Position Size]
input double        InpLotSize           = 0.01;      // [Position] Lot Size (Editable on Panel)

// [Risk Management]
input int           InpSlippage          = 10;     // [Risk] Slippage
input ulong         InpMagicNumber       = 999004; // [Risk] Magic Number (v1.02)
input string        InpComment           = "MerkavaWire"; // [Risk] Comment

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
input color         InpBgColor           = clrDarkSlateGray; // [UI] BG Color
input color         InpTxtColor          = clrWhite;         // [UI] Text Color

//--- Globals
bool              g_active = false;      // Is the strategy running?
int               g_log_handle = INVALID_HANDLE;
bool              g_book_subscribed = false;

// Research Globals (Indicators)
int               h_hybrid = INVALID_HANDLE;
int               h_flow = INVALID_HANDLE;

string            g_last_action = "IDLE";
double            g_last_realized_pl = 0.0;
double            g_session_realized_pl = 0.0;
string            g_tick_event_buffer = "";
string            g_decision_log = ""; // Detailed Decision Logic

// User Controllable Globals
double            g_user_lot_size = InpLotSize;

//--- GUI Objects
string Prefix = "MerkavaWire_";
string ObjBG = Prefix + "BG";
string ObjStat = Prefix + "Status";
string ObjBtnFire = Prefix + "BtnFire";
string ObjBtnClear = Prefix + "BtnClear";
string ObjEditLot = Prefix + "EditLot";
string ObjLabelLot = Prefix + "LabelLot";
string ObjLabelPL = Prefix + "LabelPL";

//--- Forward Declarations
void CreatePanel();
void UpdateUI();
void DestroyPanel();
void CleanupChart();
void RemoveIndicators();
double NormalizeLot(double lot);
void WriteLog();
double GetFloatingPL();

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

   // Init FireControl
   m_fire_control.Init(&m_trade, &m_symbol, InpComment, InpMagicNumber);

   // --- INDICATOR HANDLES ---
   string path_hybrid = InpIndPath + "Jules_Hybrid_Momentum_Pulse_v1.04";
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

   // Init Log
   string time_str = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(time_str, ":", ""); StringReplace(time_str, " ", "_");
   string filename = "Mimic_Merkava_WIRE_" + _Symbol + "_v1.02_" + time_str + ".csv";
   g_log_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(g_log_handle != INVALID_HANDLE) {
      string header = "Time,TickMS,Action,LotSize,Bid,Ask,Spread,Velocity,Hybrid_MACD,Hybrid_Color,Hybrid_DFCurve,Flow_MFI,Flow_DUp,Flow_DDown,Floating_PL,Realized_PL,Session_PL,PosCount,Decision_Log\r\n";
      FileWriteString(g_log_handle, header);
      FileFlush(g_log_handle);
   }

   CreatePanel();
   UpdateUI();

   Print("Merkava Wire EA v1.02 Initialized.");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   DestroyPanel();
   CleanupChart();
   RemoveIndicators();
   if(g_book_subscribed) MarketBookRelease(_Symbol);
   if(h_hybrid != INVALID_HANDLE) IndicatorRelease(h_hybrid);
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
      if(StringFind(name, "#") == 0) // Delete arrows? No, keep history for now
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
      if(sparam == ObjBtnFire)
        {
         // FIRE BURST
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         ChartRedraw();

         double center = (m_symbol.Ask() + m_symbol.Bid()) / 2.0;
         m_fire_control.FireBurst(center, g_user_lot_size, InpLayers, InpSpreadMultStart, InpSpreadMultStep, InpSafeZonePts);
         g_last_action = "BURST_FIRED";
         g_decision_log += "Burst Fired L" + IntegerToString(InpLayers) + ";";

         Sleep(100);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw();
        }
      else if (sparam == ObjBtnClear)
        {
         // CEASE FIRE
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         m_fire_control.CeaseFire();
         g_last_action = "CEASE_FIRE";
         g_decision_log += "Cease Fire;";
         Sleep(100);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
        UpdateUI();
     }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
     {
      if(sparam == ObjEditLot) {
           string text = ObjectGetString(0, ObjEditLot, OBJPROP_TEXT);
           double val = StringToDouble(text);
           if(val > 0) g_user_lot_size = val;
           Print("Merkava: Lot Size Updated to: ", g_user_lot_size);
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
   g_decision_log = "";
  }

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void WriteLog()
  {
   if(g_log_handle == INVALID_HANDLE) return;

   // 1. Indicators
   double buf[1];
   double hybrid_macd=0, hybrid_color=0, hybrid_curve=0;
   double flow_mfi=0, flow_dup=0, flow_ddown=0;

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

   PhysicsState p = m_physics.GetState();
   double float_pl = GetFloatingPL();
   int pos_count = PositionsTotal();

   string row = StringFormat("%s,%s,%s,%.2f,%.5f,%.5f,%.1f,%.5f,%.5f,%.0f,%.5f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%s",
       TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
       IntegerToString(GetTickCount()%1000),
       g_last_action,
       g_user_lot_size,
       m_symbol.Bid(), m_symbol.Ask(), p.spread_avg,
       p.velocity,
       hybrid_macd, hybrid_color, hybrid_curve,
       flow_mfi, flow_dup, flow_ddown,
       float_pl, g_last_realized_pl, g_session_realized_pl,
       pos_count,
       g_decision_log
   );

   FileWriteString(g_log_handle, row + "\r\n");
   FileFlush(g_log_handle);

   if (g_last_action != "IDLE") g_last_action = "IDLE"; // Reset action flag
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

//+------------------------------------------------------------------+
//| GUI                                                              |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x = InpX, y = InpY, w = 140, h = 200;

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
   ObjectSetString(0, ObjStat, OBJPROP_TEXT, "MERKAVA v1.02");
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

   // FIRE Button
   ObjectCreate(0, ObjBtnFire, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_YSIZE, 40);
   ObjectSetString(0, ObjBtnFire, OBJPROP_TEXT, "FIRE BURST");
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_BGCOLOR, clrRed);
   ObjectSetInteger(0, ObjBtnFire, OBJPROP_COLOR, clrWhite);
   cy += 50;

   // CLEAR Button
   ObjectCreate(0, ObjBtnClear, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ObjBtnClear, OBJPROP_TEXT, "CEASE FIRE");
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_BGCOLOR, clrOrange);
   ObjectSetInteger(0, ObjBtnClear, OBJPROP_COLOR, clrBlack);
   cy += 40;

   ObjectCreate(0, ObjLabelPL, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, ObjLabelPL, OBJPROP_COLOR, clrWhite);
  }

void UpdateUI()
  {
   ObjectSetString(0, ObjLabelPL, OBJPROP_TEXT, "PL: " + DoubleToString(GetFloatingPL(), 2));
   ChartRedraw();
  }

void DestroyPanel()
  {
   ObjectDelete(0, ObjBG); ObjectDelete(0, ObjStat);
   ObjectDelete(0, ObjBtnFire); ObjectDelete(0, ObjBtnClear);
   ObjectDelete(0, ObjEditLot); ObjectDelete(0, ObjLabelLot);
   ObjectDelete(0, ObjLabelPL);
  }
