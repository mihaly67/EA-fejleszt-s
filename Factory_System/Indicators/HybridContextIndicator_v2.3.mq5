//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v2.3.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 2.3 (Configurable Line Styles & Colors)              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "2.3"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   5

//--- Plot 1-3: Main Pivot (Primary)
#property indicator_label1  "Primary Pivot P"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "Primary Pivot R1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_color2  clrRed
#property indicator_width2  1

#property indicator_label3  "Primary Pivot S1"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_DOT
#property indicator_color3  clrGreen
#property indicator_width3  1

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

input group              "=== Pivot Visuals (Primary) ==="
input color              InpPivotPColor        = clrBlue;
input int                InpPivotPWidth        = 2;
input ENUM_LINE_STYLE    InpPivotPStyle        = STYLE_SOLID;

input color              InpPivotR1Color       = clrRed;
input int                InpPivotR1Width       = 1;
input ENUM_LINE_STYLE    InpPivotR1Style       = STYLE_DOT;

input color              InpPivotS1Color       = clrGreen;
input int                InpPivotS1Width       = 1;
input ENUM_LINE_STYLE    InpPivotS1Style       = STYLE_DOT;

input group              "=== Pivot Visuals (Secondary) ==="
input color              InpSecPivotPColor     = clrBlue;
input int                InpSecPivotPWidth     = 1;          // Thinner default
input ENUM_LINE_STYLE    InpSecPivotPStyle     = STYLE_DOT;

input color              InpSecPivotR1Color    = clrRed;
input int                InpSecPivotR1Width    = 1;
input ENUM_LINE_STYLE    InpSecPivotR1Style    = STYLE_DOT;

input color              InpSecPivotS1Color    = clrGreen;
input int                InpSecPivotS1Width    = 1;
input ENUM_LINE_STYLE    InpSecPivotS1Style    = STYLE_DOT;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

input group              "=== Trend Visuals ==="
input color              InpTrendFastColor     = clrOrange;
input int                InpTrendFastWidth     = 2;
input ENUM_LINE_STYLE    InpTrendFastStyle     = STYLE_SOLID;

input color              InpTrendSlowColor     = clrDarkTurquoise;
input int                InpTrendSlowWidth     = 2;
input ENUM_LINE_STYLE    InpTrendSlowStyle     = STYLE_SOLID;

input group              "=== Smart Fibo Settings ==="
input bool               InpShowFibo           = true;
input int                InpSwingLookback      = 20;         // Lookback for High/Low search on Pivot TF
input color              InpFiboColor          = clrGoldenrod;
input int                InpFiboWidth          = 1;          // Thinner default (Requested)
input ENUM_LINE_STYLE    InpFiboStyle          = STYLE_DASH; // Configurable style

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

    // Adjusted Logic: Tighter pivot alignment for "smallest pivot" logic
    // M1, M5 -> M15 Pivots (Was M30) - Aligns with Micro Trend
    // M15, M30 -> H1 Pivots (Was H4)
    // H1, H4 -> D1 Pivots

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

    // P Line
    if(ObjectFind(0, p_name) < 0) ObjectCreate(0, p_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, p_name, OBJPROP_PRICE, P);
    ObjectSetInteger(0, p_name, OBJPROP_COLOR, InpSecPivotPColor);
    ObjectSetInteger(0, p_name, OBJPROP_STYLE, InpSecPivotPStyle);
    ObjectSetInteger(0, p_name, OBJPROP_WIDTH, InpSecPivotPWidth);

    // R1 Line
    if(ObjectFind(0, r_name) < 0) ObjectCreate(0, r_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, r_name, OBJPROP_PRICE, R1);
    ObjectSetInteger(0, r_name, OBJPROP_COLOR, InpSecPivotR1Color);
    ObjectSetInteger(0, r_name, OBJPROP_STYLE, InpSecPivotR1Style);
    ObjectSetInteger(0, r_name, OBJPROP_WIDTH, InpSecPivotR1Width);

    // S1 Line
    if(ObjectFind(0, s_name) < 0) ObjectCreate(0, s_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, s_name, OBJPROP_PRICE, S1);
    ObjectSetInteger(0, s_name, OBJPROP_COLOR, InpSecPivotS1Color);
    ObjectSetInteger(0, s_name, OBJPROP_STYLE, InpSecPivotS1Style);
    ObjectSetInteger(0, s_name, OBJPROP_WIDTH, InpSecPivotS1Width);
}

//+------------------------------------------------------------------+
//| Helper: Native Swing Detection for Fibo (No External Deps)       |
//+------------------------------------------------------------------+
void UpdateFiboNative(const datetime &time[])
{
   if(!InpShowFibo) return;

   // 1. Get HTF Data (Highs/Lows)
   int lookback = InpSwingLookback * 2;
   double highs[];
   double lows[];
   datetime times[];

   if(CopyHigh(_Symbol, current_pivot_tf, 0, lookback, highs) <= 0) return;
   if(CopyLow(_Symbol, current_pivot_tf, 0, lookback, lows) <= 0) return;
   if(CopyTime(_Symbol, current_pivot_tf, 0, lookback, times) <= 0) return;

   // 2. Simple Swing Detection
   int hh_idx = -1;
   int ll_idx = -1;
   double max_h = -DBL_MAX;
   double min_l = DBL_MAX;

   // Search recent history
   for(int i = 0; i < lookback; i++)
   {
       if(highs[i] > max_h) { max_h = highs[i]; hh_idx = i; }
       if(lows[i] < min_l)  { min_l = lows[i];  ll_idx = i; }
   }

   // 3. Determine Direction
   // Reviewer Note: CopyHigh into dynamic array (non-series) puts Oldest at 0.
   // But we want to be safe and use Series indexing (0=Newest).
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(times, true);

   // Re-scan with Series Indexing (0=Newest)
   hh_idx = -1; ll_idx = -1;
   max_h = -DBL_MAX; min_l = DBL_MAX;

   for(int i = 0; i < lookback; i++)
   {
       if(highs[i] > max_h) { max_h = highs[i]; hh_idx = i; }
       if(lows[i] < min_l)  { min_l = lows[i];  ll_idx = i; }
   }

   if(hh_idx != -1 && ll_idx != -1 && hh_idx != ll_idx)
   {
       datetime t1, t2;
       double p1, p2;

       // Series Indexing: Lower Index = Newer Time.
       // If High Index (hh_idx) < Low Index (ll_idx) -> High is NEWER -> Uptrend
       if(hh_idx < ll_idx)
       {
           t1 = times[ll_idx]; p1 = min_l; // Old (Low)
           t2 = times[hh_idx]; p2 = max_h; // New (High)
       }
       else // Low is Newer -> Downtrend
       {
           t1 = times[hh_idx]; p1 = max_h; // Old (High)
           t2 = times[ll_idx]; p2 = min_l; // New (Low)
       }

       string name = "HybridSmartFibo";
       if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_FIBO, 0, 0, 0);

       ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
       ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
       ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
       ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);

       // User Configurable Visuals
       ObjectSetInteger(0, name, OBJPROP_COLOR, InpFiboColor);
       ObjectSetInteger(0, name, OBJPROP_STYLE, InpFiboStyle);
       ObjectSetInteger(0, name, OBJPROP_WIDTH, InpFiboWidth);

       ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
       ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

       string desc = StringFormat("Micro Fibo (%s)", EnumToString(current_pivot_tf));
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

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v2.3 (Configurable)");

   current_pivot_tf = GetOptimalPivotTF();

   if(InpShowTrends)
   {
      ema_fast_handle = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

   // Apply Visual Settings to Indicator Buffers (Plots)
   // Plot 0 (Index 0): Pivot P
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpPivotPColor);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpPivotPStyle);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpPivotPWidth);

   // Plot 1 (Index 1): Pivot R1
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpPivotR1Color);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpPivotR1Style);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpPivotR1Width);

   // Plot 2 (Index 2): Pivot S1
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpPivotS1Color);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpPivotS1Style);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpPivotS1Width);

   // Plot 3 (Index 3): Trend Fast
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpTrendFastColor);
   PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpTrendFastStyle);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpTrendFastWidth);

   // Plot 4 (Index 4): Trend Slow
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpTrendSlowColor);
   PlotIndexSetInteger(4, PLOT_LINE_STYLE, InpTrendSlowStyle);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpTrendSlowWidth);

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

   // --- 3. Smart Fibo (Native) ---
   if(InpShowFibo && prev_calculated < rates_total)
   {
       UpdateFiboNative(time);
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   if(InpShowFibo) ObjectDelete(0, "HybridSmartFibo");
   if(InpShowSecondaryPivot)
   {
       ObjectDelete(0, "SecPivot_P");
       ObjectDelete(0, "SecPivot_R1");
       ObjectDelete(0, "SecPivot_S1");
   }

   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
}
