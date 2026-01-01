//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v2.7.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 2.7 (Solid Secondary Pivots & Cleanup)                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.7"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   5

//--- Plot 1-3: Main Pivot (Primary)
#property indicator_label1  "Primary Pivot P"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrBlue
#property indicator_width1  1 // Thinnest Solid

#property indicator_label2  "Primary Pivot R1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_color2  clrRed
#property indicator_width2  1 // Thinnest Solid

#property indicator_label3  "Primary Pivot S1"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_SOLID
#property indicator_color3  clrGreen
#property indicator_width3  1 // Thinnest Solid

//--- Plot 4-5: Trend EMAs
#property indicator_label4  "Trend EMA Fast"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_SOLID
#property indicator_color4  clrOrange
#property indicator_width4  2

#property indicator_label5  "Trend EMA Slow"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_SOLID
#property indicator_color5  clrDarkTurquoise
#property indicator_width5  2

//--- Input Parameters
input group              "=== Intelligent Pivot Settings ==="
input bool               InpShowPivots         = true;
input bool               InpAutoMode           = true;       // Automatikus idősík választás (Micro-Align)
input ENUM_TIMEFRAMES    InpManualPivotTF      = PERIOD_H4;  // Manuális beállítás
input bool               InpShowSecondaryPivot = true;
input ENUM_TIMEFRAMES    InpSecondaryPivotTF   = PERIOD_H1;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

input group              "=== Smart Fibo Settings (Objects) ==="
input bool               InpShowFibo           = true;
input int                InpSwingLookback      = 20;         // Lookback for High/Low search
input color              InpFiboColor          = clrKhaki;   // Minimally Greyed Yellow (Soft)
input int                InpFiboWidth          = 1;          // Thinnest default
input ENUM_LINE_STYLE    InpFiboStyle          = STYLE_SOLID;// User specified Line

input group              "=== Secondary Pivot Settings (Objects) ==="
// Note: These remain as Inputs because they are Objects, not Plots
input color              InpSecPivotPColor     = clrBlue;
input int                InpSecPivotPWidth     = 1;
input ENUM_LINE_STYLE    InpSecPivotPStyle     = STYLE_SOLID; // Changed from STYLE_DOT

input color              InpSecPivotR1Color    = clrRed;
input int                InpSecPivotR1Width    = 1;
input ENUM_LINE_STYLE    InpSecPivotR1Style    = STYLE_SOLID; // Changed from STYLE_DOT

input color              InpSecPivotS1Color    = clrGreen;
input int                InpSecPivotS1Width    = 1;
input ENUM_LINE_STYLE    InpSecPivotS1Style    = STYLE_SOLID; // Changed from STYLE_DOT

//--- Buffers
double      PivotPBuffer[];
double      PivotR1Buffer[];
double      PivotS1Buffer[];
double      TrendFastBuffer[];
double      TrendSlowBuffer[];

//--- Global Handles
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//--- State Variables
ENUM_TIMEFRAMES current_pivot_tf;

//+------------------------------------------------------------------+
//| Helper: Determine Optimal Pivot Timeframe (Tighter for Micro)    |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetOptimalPivotTF()
{
    if(!InpAutoMode) return InpManualPivotTF;
    if(_Period <= PERIOD_M5) return PERIOD_M15;
    if(_Period <= PERIOD_M30) return PERIOD_H1;
    if(_Period <= PERIOD_H4) return PERIOD_D1;
    return PERIOD_W1;
}

//+------------------------------------------------------------------+
//| Helper: Get Pivot Data from HTF                                  |
//+------------------------------------------------------------------+
bool GetPivotData(datetime time, ENUM_TIMEFRAMES tf, double &P, double &R1, double &S1)
{
   datetime htf_time = iTime(_Symbol, tf, iBarShift(_Symbol, tf, time));
   int shift = iBarShift(_Symbol, tf, htf_time) + 1;

   if(shift < 0) return false;

   double high = iHigh(_Symbol, tf, shift);
   double low  = iLow(_Symbol, tf, shift);
   double close = iClose(_Symbol, tf, shift);

   if(high == 0 || low == 0) return false;

   P = (high + low + close) / 3.0;
   R1 = (2.0 * P) - low;
   S1 = (2.0 * P) - high;

   return true;
}

//+------------------------------------------------------------------+
//| Helper: Draw Secondary Pivot Lines (Objects)                     |
//+------------------------------------------------------------------+
void UpdateSecondaryPivot(datetime time, double P, double R1, double S1)
{
    string p_name = "SecPivot_P";
    string r_name = "SecPivot_R1";
    string s_name = "SecPivot_S1";

    if(ObjectFind(0, p_name) < 0) ObjectCreate(0, p_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, p_name, OBJPROP_PRICE, P);
    ObjectSetInteger(0, p_name, OBJPROP_COLOR, InpSecPivotPColor);
    ObjectSetInteger(0, p_name, OBJPROP_STYLE, InpSecPivotPStyle);
    ObjectSetInteger(0, p_name, OBJPROP_WIDTH, InpSecPivotPWidth);

    if(ObjectFind(0, r_name) < 0) ObjectCreate(0, r_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, r_name, OBJPROP_PRICE, R1);
    ObjectSetInteger(0, r_name, OBJPROP_COLOR, InpSecPivotR1Color);
    ObjectSetInteger(0, r_name, OBJPROP_STYLE, InpSecPivotR1Style);
    ObjectSetInteger(0, r_name, OBJPROP_WIDTH, InpSecPivotR1Width);

    if(ObjectFind(0, s_name) < 0) ObjectCreate(0, s_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, s_name, OBJPROP_PRICE, S1);
    ObjectSetInteger(0, s_name, OBJPROP_COLOR, InpSecPivotS1Color);
    ObjectSetInteger(0, s_name, OBJPROP_STYLE, InpSecPivotS1Style);
    ObjectSetInteger(0, s_name, OBJPROP_WIDTH, InpSecPivotS1Width);
}

//+------------------------------------------------------------------+
//| Helper: Native Swing Detection for Fibo (Last High/Low)          |
//+------------------------------------------------------------------+
void UpdateFiboNative(const datetime &time[])
{
   if(!InpShowFibo) return;

   int lookback = InpSwingLookback * 3;
   double highs[];
   double lows[];
   datetime times[];

   if(CopyHigh(_Symbol, _Period, 0, lookback, highs) <= 0) return;
   if(CopyLow(_Symbol, _Period, 0, lookback, lows) <= 0) return;
   if(CopyTime(_Symbol, _Period, 0, lookback, times) <= 0) return;

   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(times, true);

   int hh_idx = -1;
   int ll_idx = -1;
   double max_h = -DBL_MAX;
   double min_l = DBL_MAX;

   for(int i = 0; i < lookback; i++)
   {
       if(highs[i] > max_h) { max_h = highs[i]; hh_idx = i; }
       if(lows[i] < min_l)  { min_l = lows[i];  ll_idx = i; }
   }

   if(hh_idx != -1 && ll_idx != -1 && hh_idx != ll_idx)
   {
       datetime t1, t2;
       double p1, p2;

       if(hh_idx < ll_idx)
       {
           t1 = times[ll_idx]; p1 = min_l; // Start (Low)
           t2 = times[hh_idx]; p2 = max_h; // End (High)
       }
       else
       {
           t1 = times[hh_idx]; p1 = max_h; // Start (High)
           t2 = times[ll_idx]; p2 = min_l; // End (Low)
       }

       string name = "HybridSmartFibo";
       if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_FIBO, 0, 0, 0);

       ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
       ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
       ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
       ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);

       ObjectSetInteger(0, name, OBJPROP_COLOR, InpFiboColor);
       ObjectSetInteger(0, name, OBJPROP_STYLE, InpFiboStyle);
       ObjectSetInteger(0, name, OBJPROP_WIDTH, InpFiboWidth);

       ObjectSetInteger(0, name, OBJPROP_LEVELS, 6);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 0, 0.0);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 1, 0.236);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 2, 0.382);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 3, 0.5);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 4, 0.618);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 5, 1.0);

       ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, InpFiboColor);
       ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, InpFiboStyle);
       ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, InpFiboWidth);

       ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
       ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

       string desc = "Smart Fibo (Last Swing)";
       ObjectSetString(0, name, OBJPROP_TEXT, desc);
   }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, PivotPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, PivotR1Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, PivotS1Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, TrendFastBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, TrendSlowBuffer, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v2.7");

   current_pivot_tf = GetOptimalPivotTF();

   if(InpShowTrends)
   {
      ema_fast_handle = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

   // REMOVED PlotIndexSetInteger overrides to allow Colors Tab usage for buffers

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // --- 1. Primary Pivots (Buffer based) ---
   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         double P, R1, S1;
         if(GetPivotData(time[i], current_pivot_tf, P, R1, S1))
         {
            PivotPBuffer[i] = P;
            PivotR1Buffer[i] = R1;
            PivotS1Buffer[i] = S1;
         }
         else if(i > 0)
         {
             PivotPBuffer[i] = PivotPBuffer[i-1];
             PivotR1Buffer[i] = PivotR1Buffer[i-1];
             PivotS1Buffer[i] = PivotS1Buffer[i-1];
         }
      }

      if(InpShowSecondaryPivot)
      {
          double P2, R12, S12;
          if(GetPivotData(time[rates_total-1], InpSecondaryPivotTF, P2, R12, S12))
          {
              UpdateSecondaryPivot(time[rates_total-1], P2, R12, S12);
          }
      }
   }

   // --- 2. Trends ---
   if(InpShowTrends)
   {
      if(ema_fast_handle != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, rates_total, TrendFastBuffer);
      if(ema_slow_handle != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, rates_total, TrendSlowBuffer);
   }

   // --- 3. Smart Fibo (Native Object) ---
   if(InpShowFibo && (prev_calculated == rates_total || prev_calculated == 0))
   {
       UpdateFiboNative(time);
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, "HybridSmartFibo");
   ObjectDelete(0, "SecPivot_P");
   ObjectDelete(0, "SecPivot_R1");
   ObjectDelete(0, "SecPivot_S1");

   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
}
