//+------------------------------------------------------------------+
//|                                    HybridContextIndicator_v3.12.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.12 (ZigZag Fix & Visual Controls)                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.12"

#property indicator_chart_window
// 2 Tiers * 3 Lines = 6 Buffers + 2 Trends = 8 Buffers
#property indicator_buffers 8
#property indicator_plots   8

//--- 1. MICRO PIVOT (ZigZag Fast) - DOT
#property indicator_label1  "Micro Pivot P"
#property indicator_type1   DRAW_LINE
#property indicator_style1  STYLE_DOT
#property indicator_color1  clrBlue
#property indicator_width1  1

#property indicator_label2  "Micro Pivot R1"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_color2  clrRed
#property indicator_width2  1

#property indicator_label3  "Micro Pivot S1"
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_DOT
#property indicator_color3  clrGreen
#property indicator_width3  1

//--- 2. SECONDARY PIVOT (ZigZag Slow / Barrier) - SOLID (Defaults overridden by Inputs)
#property indicator_label4  "Secondary Pivot P"
#property indicator_type4   DRAW_LINE
#property indicator_style4  STYLE_SOLID
#property indicator_color4  clrDarkBlue
#property indicator_width4  2

#property indicator_label5  "Secondary Pivot R1"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_SOLID
#property indicator_color5  clrDarkRed
#property indicator_width5  2

#property indicator_label6  "Secondary Pivot S1"
#property indicator_type6   DRAW_LINE
#property indicator_style6  STYLE_SOLID
#property indicator_color6  clrDarkGreen
#property indicator_width6  2

//--- 3. TRENDS
#property indicator_label7  "Trend EMA Fast"
#property indicator_type7   DRAW_LINE
#property indicator_style7  STYLE_SOLID
#property indicator_color7  clrOrange
#property indicator_width7  1

#property indicator_label8  "Trend EMA Slow"
#property indicator_type8   DRAW_LINE
#property indicator_style8  STYLE_SOLID
#property indicator_color8  clrDarkTurquoise
#property indicator_width8  1

//--- Input Parameters
input group              "=== Micro ZigZag (Fast) Settings ==="
input int                InpMicroDepth         = 5;
input int                InpMicroDeviation     = 5;
input int                InpMicroBackstep      = 3;
input ENUM_LINE_STYLE    InpMicroStyle         = STYLE_DOT;
input int                InpMicroWidth         = 1;

input group              "=== Secondary ZigZag (Slow) Settings ==="
input int                InpSecDepth           = 30;
input int                InpSecDeviation       = 10;
input int                InpSecBackstep        = 5;
// Explicit Visual Controls for Secondary
input color              InpSecColorP          = clrDarkBlue;
input color              InpSecColorR1         = clrDarkRed;
input color              InpSecColorS1         = clrDarkGreen;
input ENUM_LINE_STYLE    InpSecStyle           = STYLE_SOLID;
input int                InpSecWidth           = 2;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

//--- Buffers
double      MicroP[], MicroR1[], MicroS1[];
double      SecP[], SecR1[], SecS1[];
double      TrendFast[], TrendSlow[];

//--- ZigZag Helper Buffers (Internal)
double      MicroZZHigh[], MicroZZLow[];
double      SecZZHigh[], SecZZLow[];

//--- Global Handles
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Internal ZigZag Calculation Logic                                |
//+------------------------------------------------------------------+
void CalculateZigZag(const int rates_total, const int prev_calculated,
                     const double &high[], const double &low[],
                     int depth, int deviation, int backstep,
                     double &out_high[], double &out_low[])
{
   // FIXED: Look back sufficiently to update the last swing.
   // Standard ZigZag often re-calculates the last leg.
   // A safe margin is ~200 bars or at least 3*Depth.
   int recalc_lookback = depth * 10;
   if (recalc_lookback < 200) recalc_lookback = 200;

   int start = rates_total - recalc_lookback;
   if (start < depth) start = depth;
   if (prev_calculated == 0) start = depth;
   // We ignore prev_calculated optimization partially to ensure the "tail" is correct.

   // 1. Search for Highs/Lows
   for(int i = start; i < rates_total; i++)
   {
      double val_h = high[i];
      int highest = i;
      for(int k = 1; k <= depth; k++)
      {
         if(i-k < 0) break;
         if(high[i-k] > val_h) { val_h = high[i-k]; highest = i-k; }
      }
      if(val_h == high[i]) out_high[i] = val_h; else out_high[i] = 0.0;

      double val_l = low[i];
      int lowest = i;
      for(int k = 1; k <= depth; k++)
      {
         if(i-k < 0) break;
         if(low[i-k] < val_l) { val_l = low[i-k]; lowest = i-k; }
      }
      if(val_l == low[i]) out_low[i] = val_l; else out_low[i] = 0.0;
   }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Micro
   SetIndexBuffer(0, MicroP, INDICATOR_DATA);
   SetIndexBuffer(1, MicroR1, INDICATOR_DATA);
   SetIndexBuffer(2, MicroS1, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpMicroWidth);

   // 2. Secondary
   SetIndexBuffer(3, SecP, INDICATOR_DATA);
   SetIndexBuffer(4, SecR1, INDICATOR_DATA);
   SetIndexBuffer(5, SecS1, INDICATOR_DATA);

   // Apply Visual Inputs
   PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpSecColorP);

   PlotIndexSetInteger(4, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpSecColorR1);

   PlotIndexSetInteger(5, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpSecColorS1);

   // 3. Trends
   SetIndexBuffer(6, TrendFast, INDICATOR_DATA);
   SetIndexBuffer(7, TrendSlow, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.12");

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
   if(rates_total < InpSecDepth + 100) return 0;

   if(ArraySize(MicroZZHigh) < rates_total) { ArrayResize(MicroZZHigh, rates_total); ArrayResize(MicroZZLow, rates_total); }
   if(ArraySize(SecZZHigh) < rates_total) { ArrayResize(SecZZHigh, rates_total); ArrayResize(SecZZLow, rates_total); }

   CalculateZigZag(rates_total, prev_calculated, high, low, InpMicroDepth, InpMicroDeviation, InpMicroBackstep, MicroZZHigh, MicroZZLow);
   CalculateZigZag(rates_total, prev_calculated, high, low, InpSecDepth, InpSecDeviation, InpSecBackstep, SecZZHigh, SecZZLow);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
      // ----------------------------------------------------
      // 1. MICRO PIVOT (Last Non-Zero Micro ZigZag)
      // ----------------------------------------------------
      double m_r = (i > 0) ? MicroR1[i-1] : high[i];
      double m_s = (i > 0) ? MicroS1[i-1] : low[i];

      // Search backwards from 'i'
      int limit_search = 200;
      for(int k=i; k > i - limit_search && k >= 0; k--) {
         if(MicroZZHigh[k] != 0) { m_r = MicroZZHigh[k]; break; }
      }
      for(int k=i; k > i - limit_search && k >= 0; k--) {
         if(MicroZZLow[k] != 0) { m_s = MicroZZLow[k]; break; }
      }

      MicroR1[i] = m_r;
      MicroS1[i] = m_s;
      MicroP[i]  = (m_r + m_s + close[i]) / 3.0;

      // ----------------------------------------------------
      // 2. SECONDARY PIVOT (Barrier Logic with ZigZag)
      // ----------------------------------------------------
      double s_r = (i > 0) ? SecR1[i-1] : m_r;
      double s_s = (i > 0) ? SecS1[i-1] : m_s;

      bool r_broken = (close[i] > s_r);
      bool s_broken = (close[i] < s_s);

      if(s_r == 0 || s_r <= m_r || r_broken)
      {
         s_r = -1;
         int scan_limit = 5000;
         for(int k=i; k > i - scan_limit && k >= 0; k--) {
            if(SecZZHigh[k] != 0) {
               if(SecZZHigh[k] > close[i]) {
                  s_r = SecZZHigh[k];
                  break;
               }
            }
         }
         // Fallback if ATH or no barrier found
         if(s_r == -1 && i > 0) s_r = SecR1[i-1];
         if(s_r == -1) s_r = high[i] * 1.05; // Fallback so it is drawn at least
      }

      if(s_s == 0 || s_s >= m_s || s_broken)
      {
         s_s = 999999;
         int scan_limit = 5000;
         for(int k=i; k > i - scan_limit && k >= 0; k--) {
            if(SecZZLow[k] != 0) {
               if(SecZZLow[k] < close[i]) {
                  s_s = SecZZLow[k];
                  break;
               }
            }
         }
         if(s_s == 999999 && i > 0) s_s = SecS1[i-1];
         if(s_s == 999999) s_s = low[i] * 0.95;
      }

      SecR1[i] = s_r;
      SecS1[i] = s_s;
      SecP[i]  = (s_r + s_s + close[i]) / 3.0;
   }

   if(InpShowTrends)
   {
      if(ema_fast_handle != INVALID_HANDLE) CopyBuffer(ema_fast_handle, 0, 0, rates_total, TrendFast);
      if(ema_slow_handle != INVALID_HANDLE) CopyBuffer(ema_slow_handle, 0, 0, rates_total, TrendSlow);
   }

   return rates_total;
}

void OnDeinit(const int reason)
{
   if(ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
   if(ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);

   ArrayFree(MicroZZHigh);
   ArrayFree(MicroZZLow);
   ArrayFree(SecZZHigh);
   ArrayFree(SecZZLow);
}
