//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v3.4.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.4 (Fully Auto Scalping Pivots: M15/M30/H1)         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.4"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   5

//--- Plot 1-3: Main Pivot (Primary/Micro) - DOT
#property indicator_label1  "Primary Pivot P"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_DOT
#property indicator_color1  clrBlue
#property indicator_width1  1

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
input bool               InpAutoMode           = true;       // Fully Auto: M15 -> M30 -> H1
input ENUM_TIMEFRAMES    InpManualPivotTF      = PERIOD_M15; // Used only if AutoMode=false
input bool               InpShowSecondaryPivot = true;
input ENUM_TIMEFRAMES    InpSecondaryPivotTF   = PERIOD_M30; // Used only if AutoMode=false
input bool               InpShowTertiaryPivot  = true;
input ENUM_TIMEFRAMES    InpTertiaryPivotTF    = PERIOD_H1;  // Used only if AutoMode=false

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
input ENUM_LINE_STYLE    InpSecPivotPStyle     = STYLE_DASH; // DASH

input color              InpSecPivotR1Color    = clrRed;
input int                InpSecPivotR1Width    = 1;
input ENUM_LINE_STYLE    InpSecPivotR1Style    = STYLE_DASH; // DASH

input color              InpSecPivotS1Color    = clrGreen;
input int                InpSecPivotS1Width    = 1;
input ENUM_LINE_STYLE    InpSecPivotS1Style    = STYLE_DASH; // DASH

input group              "=== Tertiary Pivot Settings (Objects) ==="
input color              InpTerPivotPColor     = clrBlue;
input int                InpTerPivotPWidth     = 1;
input ENUM_LINE_STYLE    InpTerPivotPStyle     = STYLE_DASHDOT; // DASHDOT

input color              InpTerPivotR1Color    = clrRed;
input int                InpTerPivotR1Width    = 1;
input ENUM_LINE_STYLE    InpTerPivotR1Style    = STYLE_DASHDOT; // DASHDOT

input color              InpTerPivotS1Color    = clrGreen;
input int                InpTerPivotS1Width    = 1;
input ENUM_LINE_STYLE    InpTerPivotS1Style    = STYLE_DASHDOT; // DASHDOT

//--- Buffers
double      PivotPBuffer[];
double      PivotR1Buffer[];
double      PivotS1Buffer[];
double      TrendFastBuffer[];
double      TrendSlowBuffer[];

//--- Global Handles
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//--- State Variables (Dynamic TFs)
ENUM_TIMEFRAMES current_pivot_tf_prim;
ENUM_TIMEFRAMES current_pivot_tf_sec;
ENUM_TIMEFRAMES current_pivot_tf_ter;

//+------------------------------------------------------------------+
//| Helper: Determine Auto Pivot Hierarchy                           |
//+------------------------------------------------------------------+
void UpdateAutoTimeframes()
{
    if(!InpAutoMode)
    {
        current_pivot_tf_prim = InpManualPivotTF;
        current_pivot_tf_sec  = InpSecondaryPivotTF;
        current_pivot_tf_ter  = InpTertiaryPivotTF;
        return;
    }

    // SCALPING LOGIC (M1-M5)
    if(_Period <= PERIOD_M5)
    {
        current_pivot_tf_prim = PERIOD_M15;
        current_pivot_tf_sec  = PERIOD_M30;
        current_pivot_tf_ter  = PERIOD_H1;
    }
    // MID LOGIC (M15-M30)
    else if(_Period <= PERIOD_M30)
    {
        current_pivot_tf_prim = PERIOD_H1;
        current_pivot_tf_sec  = PERIOD_H4;
        current_pivot_tf_ter  = PERIOD_D1;
    }
    // SWING LOGIC (H1+)
    else
    {
        current_pivot_tf_prim = PERIOD_D1;
        current_pivot_tf_sec  = PERIOD_W1;
        current_pivot_tf_ter  = PERIOD_MN1;
    }
}

//+------------------------------------------------------------------+
//| Helper: Get Pivot Data from HTF (Previous Completed Bar)         |
//+------------------------------------------------------------------+
bool GetPivotData(datetime time, ENUM_TIMEFRAMES tf, double &P, double &R1, double &S1)
{
   // Find the Bar index on HTF that corresponds to 'time'
   int shift_htf = iBarShift(_Symbol, tf, time);

   // We want the PREVIOUS completed bar relative to that time.
   // If 'time' is inside a forming HTF bar, iBarShift gives that forming bar (index 0 relative to now).
   // +1 gives the previous completed one.
   int pivot_idx = shift_htf + 1;

   if(pivot_idx < 0) return false;

   double high = iHigh(_Symbol, tf, pivot_idx);
   double low  = iLow(_Symbol, tf, pivot_idx);
   double close = iClose(_Symbol, tf, pivot_idx);

   if(high == 0 || low == 0) return false;

   P = (high + low + close) / 3.0;
   R1 = (2.0 * P) - low;
   S1 = (2.0 * P) - high;

   return true;
}

//+------------------------------------------------------------------+
//| Helper: Draw Pivot Objects                                       |
//+------------------------------------------------------------------+
void UpdatePivotObject(string prefix, datetime time, double P, double R1, double S1,
                       color cP, color cR, color cS,
                       ENUM_LINE_STYLE sP, ENUM_LINE_STYLE sR, ENUM_LINE_STYLE sS,
                       int wP, int wR, int wS)
{
    string p_name = prefix + "_P";
    string r_name = prefix + "_R1";
    string s_name = prefix + "_S1";

    // P
    if(ObjectFind(0, p_name) < 0) ObjectCreate(0, p_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, p_name, OBJPROP_PRICE, P);
    ObjectSetInteger(0, p_name, OBJPROP_COLOR, cP);
    ObjectSetInteger(0, p_name, OBJPROP_STYLE, sP);
    ObjectSetInteger(0, p_name, OBJPROP_WIDTH, wP);
    ObjectSetInteger(0, p_name, OBJPROP_BACK, true);

    // R1
    if(ObjectFind(0, r_name) < 0) ObjectCreate(0, r_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, r_name, OBJPROP_PRICE, R1);
    ObjectSetInteger(0, r_name, OBJPROP_COLOR, cR);
    ObjectSetInteger(0, r_name, OBJPROP_STYLE, sR);
    ObjectSetInteger(0, r_name, OBJPROP_WIDTH, wR);
    ObjectSetInteger(0, r_name, OBJPROP_BACK, true);

    // S1
    if(ObjectFind(0, s_name) < 0) ObjectCreate(0, s_name, OBJ_HLINE, 0, 0, 0);
    ObjectSetDouble(0, s_name, OBJPROP_PRICE, S1);
    ObjectSetInteger(0, s_name, OBJPROP_COLOR, cS);
    ObjectSetInteger(0, s_name, OBJPROP_STYLE, sS);
    ObjectSetInteger(0, s_name, OBJPROP_WIDTH, wS);
    ObjectSetInteger(0, s_name, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Helper: Native Swing Detection for Fibo (Last High/Low)          |
//+------------------------------------------------------------------+
void UpdateFiboNative(const datetime &time[])
{
   if(!InpShowFibo) return;

   string name = "HybridSmartFibo";

   // Manual Lock
   if(ObjectFind(0, name) >= 0)
   {
       if(ObjectGetInteger(0, name, OBJPROP_SELECTED)) return;
   }

   int lookback = InpSwingLookback * 3;
   double highs[];
   double lows[];
   datetime times[];

   // Start from index 1 to avoid Creeping Zero
   if(CopyHigh(_Symbol, _Period, 1, lookback, highs) <= 0) return;
   if(CopyLow(_Symbol, _Period, 1, lookback, lows) <= 0) return;
   if(CopyTime(_Symbol, _Period, 1, lookback, times) <= 0) return;

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

       // Auto-Reverse
       if(hh_idx > ll_idx)
       {
           t1 = times[hh_idx]; p1 = max_h;
           t2 = times[ll_idx]; p2 = min_l;
       }
       else
       {
           t1 = times[ll_idx]; p1 = min_l;
           t2 = times[hh_idx]; p2 = max_h;
       }

       if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_FIBO, 0, 0, 0);

       ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
       ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
       ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
       ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);

       ObjectSetInteger(0, name, OBJPROP_COLOR, InpFiboColor);
       ObjectSetInteger(0, name, OBJPROP_STYLE, InpFiboStyle);
       ObjectSetInteger(0, name, OBJPROP_WIDTH, InpFiboWidth);

       // Scale 0-100
       int levels = 6;
       ObjectSetInteger(0, name, OBJPROP_LEVELS, levels);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 0, 0.0);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 1, 0.236);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 2, 0.382);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 3, 0.5);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 4, 0.618);
       ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 5, 1.0);

       for(int i = 0; i < levels; i++)
       {
           ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, i, InpFiboColor);
           ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, i, InpFiboStyle);
           ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, i, InpFiboWidth);

           string label = "";
           double val = ObjectGetDouble(0, name, OBJPROP_LEVELVALUE, i);
           if(val == 0.0) label = "0.0";
           else if(val == 1.0) label = "100.0";
           else label = DoubleToString(val*100, 1);
           ObjectSetString(0, name, OBJPROP_LEVELTEXT, i, label);
       }

       ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
       ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
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

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.4");

   UpdateAutoTimeframes();

   if(InpShowTrends)
   {
      ema_fast_handle = iMA(_Symbol, _Period, InpTrendFastPeriod, 0, InpTrendMethod, PRICE_CLOSE);
      ema_slow_handle = iMA(_Symbol, _Period, InpTrendSlowPeriod, 0, InpTrendMethod, PRICE_CLOSE);
   }

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

   // Refresh Auto TFs (in case chart period changes, though OnInit handles usually)
   UpdateAutoTimeframes();

   // --- 1. Primary Pivots (Buffer) -> Micro ---
   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         double P, R1, S1;
         if(GetPivotData(time[i], current_pivot_tf_prim, P, R1, S1))
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

      // --- 2. Secondary & Tertiary Pivots (Last Bar Object) ---
      if(prev_calculated == rates_total || prev_calculated == 0 || iTime(_Symbol, _Period, 0) != iTime(_Symbol, _Period, 1))
      {
          // Secondary
          if(InpShowSecondaryPivot)
          {
              double P2, R12, S12;
              if(GetPivotData(time[rates_total-1], current_pivot_tf_sec, P2, R12, S12))
              {
                  UpdatePivotObject("SecPivot", time[rates_total-1], P2, R12, S12,
                                    InpSecPivotPColor, InpSecPivotR1Color, InpSecPivotS1Color,
                                    InpSecPivotPStyle, InpSecPivotR1Style, InpSecPivotS1Style,
                                    InpSecPivotPWidth, InpSecPivotR1Width, InpSecPivotS1Width);
              }
          }

          // Tertiary
          if(InpShowTertiaryPivot)
          {
              double P3, R13, S13;
              if(GetPivotData(time[rates_total-1], current_pivot_tf_ter, P3, R13, S13))
              {
                  UpdatePivotObject("TerPivot", time[rates_total-1], P3, R13, S13,
                                    InpTerPivotPColor, InpTerPivotR1Color, InpTerPivotS1Color,
                                    InpTerPivotPStyle, InpTerPivotR1Style, InpTerPivotS1Style,
                                    InpTerPivotPWidth, InpTerPivotR1Width, InpTerPivotS1Width);
              }
          }
      }
   }

   // --- 3. Trends ---
   if(InpShowTrends)
   {
      if(ema_fast_handle != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, rates_total, TrendFastBuffer);
      if(ema_slow_handle != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, rates_total, TrendSlowBuffer);
   }

   // --- 4. Smart Fibo ---
   if(InpShowFibo)
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

   ObjectDelete(0, "TerPivot_P");
   ObjectDelete(0, "TerPivot_R1");
   ObjectDelete(0, "TerPivot_S1");

   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
}
