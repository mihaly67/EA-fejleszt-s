//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v3.7.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.7 (Fibo Disabled, Pivot Refinement Focus)          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.7"

#property indicator_chart_window
// 3 Tiers * 3 Lines = 9 Buffers + 2 Trends = 11 Buffers
#property indicator_buffers 11
#property indicator_plots   11

//--- 1. PRIMARY PIVOT (Micro) - DOT
#property indicator_label1  "Pri Pivot P"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_DOT
#property indicator_color1  clrBlue
#property indicator_width1  1

#property indicator_label2  "Pri Pivot R1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_color2  clrRed
#property indicator_width2  1

#property indicator_label3  "Pri Pivot S1"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_DOT
#property indicator_color3  clrGreen
#property indicator_width3  1

//--- 2. SECONDARY PIVOT (Mid) - DASH
#property indicator_label4  "Sec Pivot P"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_DASH
#property indicator_color4  clrBlue
#property indicator_width4  1

#property indicator_label5  "Sec Pivot R1"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_DASH
#property indicator_color5  clrRed
#property indicator_width5  1

#property indicator_label6  "Sec Pivot S1"
#property indicator_type6   DRAW_LINE
#property indicator_style6  STYLE_DASH
#property indicator_color6  clrGreen
#property indicator_width6  1

//--- 3. TERTIARY PIVOT (Macro) - DASHDOT
#property indicator_label7  "Ter Pivot P"
#property indicator_type7   DRAW_LINE
#property indicator_style7  STYLE_DASHDOT
#property indicator_color7  clrBlue
#property indicator_width7  1

#property indicator_label8  "Ter Pivot R1"
#property indicator_type8   DRAW_LINE
#property indicator_style8  STYLE_DASHDOT
#property indicator_color8  clrRed
#property indicator_width8  1

#property indicator_label9  "Ter Pivot S1"
#property indicator_type9   DRAW_LINE
#property indicator_style9  STYLE_DASHDOT
#property indicator_color9  clrGreen
#property indicator_width9  1

//--- 4. TRENDS
#property indicator_label10 "Trend EMA Fast"
#property indicator_type10  DRAW_LINE
#property indicator_style10 STYLE_SOLID
#property indicator_color10 clrOrange
#property indicator_width10 2

#property indicator_label11 "Trend EMA Slow"
#property indicator_type11  DRAW_LINE
#property indicator_style11 STYLE_SOLID
#property indicator_color11 clrDarkTurquoise
#property indicator_width11 2

//--- Input Parameters
input group              "=== Intelligent Pivot Settings ==="
input bool               InpShowPivots         = true;
input bool               InpAutoMode           = true;       // Fully Auto: M15 -> M30 -> H1
input ENUM_TIMEFRAMES    InpManualPivotTF      = PERIOD_M15; // Primary (Micro)
input bool               InpShowSecondaryPivot = true;
input ENUM_TIMEFRAMES    InpSecondaryPivotTF   = PERIOD_M30; // Secondary (Mid)
input bool               InpShowTertiaryPivot  = true;
input ENUM_TIMEFRAMES    InpTertiaryPivotTF    = PERIOD_H1;  // Tertiary (Macro)

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

input group              "=== Smart Fibo Settings (DISABLED) ==="
input bool               InpShowFibo           = false; // Disabled by default for clarity
input int                InpSwingLookback      = 20;
input color              InpFiboColor          = clrKhaki;
input int                InpFiboWidth          = 1;
input ENUM_LINE_STYLE    InpFiboStyle          = STYLE_SOLID;

//--- Buffers
double      PriP[], PriR1[], PriS1[];
double      SecP[], SecR1[], SecS1[];
double      TerP[], TerR1[], TerS1[];
double      TrendFast[], TrendSlow[];

//--- Global Handles
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//--- State Variables (Dynamic TFs)
ENUM_TIMEFRAMES current_tf_pri;
ENUM_TIMEFRAMES current_tf_sec;
ENUM_TIMEFRAMES current_tf_ter;

//+------------------------------------------------------------------+
//| Helper: Determine Auto Pivot Hierarchy                           |
//+------------------------------------------------------------------+
void UpdateAutoTimeframes()
{
    if(!InpAutoMode)
    {
        current_tf_pri = InpManualPivotTF;
        current_tf_sec = InpSecondaryPivotTF;
        current_tf_ter = InpTertiaryPivotTF;
        return;
    }

    if(_Period <= PERIOD_M5)
    {
        current_tf_pri = PERIOD_M15;
        current_tf_sec = PERIOD_M30;
        current_tf_ter = PERIOD_H1;
    }
    else if(_Period <= PERIOD_M30)
    {
        current_tf_pri = PERIOD_H1;
        current_tf_sec = PERIOD_H4;
        current_tf_ter = PERIOD_D1;
    }
    else
    {
        current_tf_pri = PERIOD_D1;
        current_tf_sec = PERIOD_W1;
        current_tf_ter = PERIOD_MN1;
    }
}

//+------------------------------------------------------------------+
//| Helper: Get Pivot Data from HTF (Previous Completed Bar)         |
//+------------------------------------------------------------------+
bool GetPivotData(datetime time, ENUM_TIMEFRAMES tf, double &P, double &R1, double &S1)
{
   int shift_htf = iBarShift(_Symbol, tf, time);
   // Rolling Logic: Use the immediately preceding completed bar relative to 'time'
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
//| Helper: Native Swing Detection for Fibo (Last High/Low)          |
//+------------------------------------------------------------------+
void UpdateFiboNative(const datetime &time[])
{
   // DISABLED IN V3.7
   if(!InpShowFibo)
   {
      // Cleanup if toggled off
      if(ObjectFind(0, "HybridSmartFibo") >= 0) ObjectDelete(0, "HybridSmartFibo");
      return;
   }

   string name = "HybridSmartFibo";

   if(ObjectFind(0, name) >= 0)
   {
       if(ObjectGetInteger(0, name, OBJPROP_SELECTED)) return;
   }

   int lookback = InpSwingLookback * 3;
   double highs[];
   double lows[];
   datetime times[];

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
   // 1. Primary
   SetIndexBuffer(0, PriP, INDICATOR_DATA);
   SetIndexBuffer(1, PriR1, INDICATOR_DATA);
   SetIndexBuffer(2, PriS1, INDICATOR_DATA);

   // 2. Secondary
   SetIndexBuffer(3, SecP, INDICATOR_DATA);
   SetIndexBuffer(4, SecR1, INDICATOR_DATA);
   SetIndexBuffer(5, SecS1, INDICATOR_DATA);

   // 3. Tertiary
   SetIndexBuffer(6, TerP, INDICATOR_DATA);
   SetIndexBuffer(7, TerR1, INDICATOR_DATA);
   SetIndexBuffer(8, TerS1, INDICATOR_DATA);

   // 4. Trends
   SetIndexBuffer(9, TrendFast, INDICATOR_DATA);
   SetIndexBuffer(10, TrendSlow, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.7");

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

   UpdateAutoTimeframes();

   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         // 1. Primary (Micro) - Calculated Standardly
         double P, R1, S1;

         // Get the time of the PRIMARY bar that this candle belongs to.
         // Example: If Primary is M15, and we are at 10:04, this gives 10:00.
         int shift_pri = iBarShift(_Symbol, current_tf_pri, time[i]);
         datetime time_pri = iTime(_Symbol, current_tf_pri, shift_pri);

         if(GetPivotData(time[i], current_tf_pri, P, R1, S1))
         {
            PriP[i] = P; PriR1[i] = R1; PriS1[i] = S1;
         }
         else if(i > 0)
         {
             PriP[i] = PriP[i-1]; PriR1[i] = PriR1[i-1]; PriS1[i] = PriS1[i-1];
         }

         // 2. Secondary (Mid) - CASCADING REFERENCE
         // We look for the pivot valid for 'time_pri' (the start of the Primary bar),
         // NOT 'time[i]' (the current minute).
         // This ensures Secondary steps only when Primary steps (or when Secondary steps naturally relative to Primary).
         if(InpShowSecondaryPivot)
         {
             if(GetPivotData(time_pri, current_tf_sec, P, R1, S1))
             {
                SecP[i] = P; SecR1[i] = R1; SecS1[i] = S1;
             }
             else if(i > 0)
             {
                SecP[i] = SecP[i-1]; SecR1[i] = SecR1[i-1]; SecS1[i] = SecS1[i-1];
             }
         }
         else
         {
             SecP[i] = EMPTY_VALUE; SecR1[i] = EMPTY_VALUE; SecS1[i] = EMPTY_VALUE;
         }

         // 3. Tertiary (Macro) - CASCADING REFERENCE
         // Similarly, relative to 'time_pri'.
         if(InpShowTertiaryPivot)
         {
             if(GetPivotData(time_pri, current_tf_ter, P, R1, S1))
             {
                TerP[i] = P; TerR1[i] = R1; TerS1[i] = S1;
             }
             else if(i > 0)
             {
                TerP[i] = TerP[i-1]; TerR1[i] = TerR1[i-1]; TerS1[i] = TerS1[i-1];
             }
         }
         else
         {
             TerP[i] = EMPTY_VALUE; TerR1[i] = EMPTY_VALUE; TerS1[i] = EMPTY_VALUE;
         }
      }
   }

   // --- Trends ---
   if(InpShowTrends)
   {
      if(ema_fast_handle != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, rates_total, TrendFast);
      if(ema_slow_handle != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, rates_total, TrendSlow);
   }

   // --- Fibo --- (DISABLED)
   // UpdateFiboNative(time);

   return rates_total;
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, "HybridSmartFibo");

   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
}
