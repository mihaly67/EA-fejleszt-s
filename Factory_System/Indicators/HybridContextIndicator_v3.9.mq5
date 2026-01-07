//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v3.9.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.9 (Fractal Stack Logic - Fix Visibility & Stability) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.9"

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
input group              "=== Barrier Logic Settings ==="
input bool               InpShowPivots         = true;
// P1 (Micro): Short-term swing (e.g. 2 bars left/right)
input int                InpP1FractalDepth     = 2;
// P2 (Mid): Medium-term swing barrier (e.g. 5 bars left/right)
input int                InpP2FractalDepth     = 5;
// P3 (Macro): Major structure barrier (e.g. 10 bars left/right)
input int                InpP3FractalDepth     = 10;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

//--- Buffers
double      PriP[], PriR1[], PriS1[];
double      SecP[], SecR1[], SecS1[];
double      TerP[], TerR1[], TerS1[];
double      TrendFast[], TrendSlow[];

//--- Global Handles
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Helper: IsFractalPeak                                            |
//+------------------------------------------------------------------+
bool IsFractalPeak(const double &high[], int idx, int depth, int total)
{
   if(idx < depth || idx >= total - depth) return false;

   double val = high[idx];
   for(int k=1; k<=depth; k++)
   {
      if(high[idx-k] > val || high[idx+k] >= val) return false; // Strict peak
   }
   return true;
}

//+------------------------------------------------------------------+
//| Helper: IsFractalTrough                                          |
//+------------------------------------------------------------------+
bool IsFractalTrough(const double &low[], int idx, int depth, int total)
{
   if(idx < depth || idx >= total - depth) return false;

   double val = low[idx];
   for(int k=1; k<=depth; k++)
   {
      if(low[idx-k] < val || low[idx+k] <= val) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, PriP, INDICATOR_DATA);
   SetIndexBuffer(1, PriR1, INDICATOR_DATA);
   SetIndexBuffer(2, PriS1, INDICATOR_DATA);

   SetIndexBuffer(3, SecP, INDICATOR_DATA);
   SetIndexBuffer(4, SecR1, INDICATOR_DATA);
   SetIndexBuffer(5, SecS1, INDICATOR_DATA);

   SetIndexBuffer(6, TerP, INDICATOR_DATA);
   SetIndexBuffer(7, TerR1, INDICATOR_DATA);
   SetIndexBuffer(8, TerS1, INDICATOR_DATA);

   SetIndexBuffer(9, TrendFast, INDICATOR_DATA);
   SetIndexBuffer(10, TrendSlow, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.9");

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
   // Need enough data for largest fractal
   if(rates_total < InpP3FractalDepth * 2 + 100) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : InpP3FractalDepth + 1;

   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         // ----------------------------------------------------
         // 1. PRIMARY P1 (Micro Fractal)
         // ----------------------------------------------------
         // Scan backwards from i-depth (because a fractal at 'i' is not known yet fully if depth>0,
         // actually standard fractal is confirmed at i-depth).
         // We look for the MOST RECENT confirmed fractal relative to 'i'.

         double p1_r = (i > 0) ? PriR1[i-1] : high[i];
         double p1_s = (i > 0) ? PriS1[i-1] : low[i];
         int p1_r_idx = -1;
         int p1_s_idx = -1;

         // Find P1 Resistance
         int search_limit_p1 = 500;
         int scan_start = i - InpP1FractalDepth;

         // Search for newest peak
         for(int k = scan_start; k > scan_start - search_limit_p1 && k >= InpP1FractalDepth; k--)
         {
            if(IsFractalPeak(high, k, InpP1FractalDepth, rates_total))
            {
               p1_r = high[k];
               p1_r_idx = k;
               break;
            }
         }

         // Search for newest trough
         for(int k = scan_start; k > scan_start - search_limit_p1 && k >= InpP1FractalDepth; k--)
         {
            if(IsFractalTrough(low, k, InpP1FractalDepth, rates_total))
            {
               p1_s = low[k];
               p1_s_idx = k;
               break;
            }
         }

         // Update P1 Buffers (Hold value if no new fractal found, logic above handles "most recent")
         // But we must check if price broke it? No, P1 is "Latest Swing", it updates when a new swing forms.
         // If price breaks P1 R1, it usually means a new Higher High swing is forming, but not confirmed yet.
         // Standard Fractal indicator behaviour: Hold lines horizontal.

         PriR1[i] = p1_r;
         PriS1[i] = p1_s;
         PriP[i]  = (p1_r + p1_s + close[i]) / 3.0;

         // ----------------------------------------------------
         // 2. SECONDARY P2 (Barrier 1)
         // ----------------------------------------------------
         // Find a "Stronger" fractal (Depth P2) that is OUTSIDE P1 range.
         // Resistance: > P1_R
         // Support: < P1_S

         double p2_r = (i > 0) ? SecR1[i-1] : p1_r;
         double p2_s = (i > 0) ? SecS1[i-1] : p1_s;
         int p2_r_idx = -1;
         int p2_s_idx = -1;

         bool p2_r_broken = (close[i] > p2_r); // If broken, we need to find the NEXT barrier
         bool p2_s_broken = (close[i] < p2_s);

         // Logic: If broken OR uninitialized, Find Next Valid Barrier
         // Search backwards starting from P1 index? Or just from current?
         // "Barrier" implies historical.

         if(p2_r == 0 || p2_r == EMPTY_VALUE || p2_r <= p1_r || p2_r_broken)
         {
             // Scan
             int limit = 2000;
             int start_k = (p1_r_idx != -1) ? p1_r_idx - 1 : i - InpP2FractalDepth;
             p2_r = -1;

             for(int k = start_k; k > start_k - limit && k >= InpP2FractalDepth; k--)
             {
                 // Must be a P2-depth fractal AND higher than P1
                 if(IsFractalPeak(high, k, InpP2FractalDepth, rates_total))
                 {
                     if(high[k] > p1_r) // Barrier found
                     {
                         p2_r = high[k];
                         p2_r_idx = k;
                         break;
                     }
                 }
             }
             // If not found, fallback to P1 (or keep empty/previous?)
             if(p2_r == -1 && i > 0) p2_r = SecR1[i-1];
             if(p2_r == -1) p2_r = p1_r; // Fallback
         }

         if(p2_s == 0 || p2_s == EMPTY_VALUE || p2_s >= p1_s || p2_s_broken)
         {
             int limit = 2000;
             int start_k = (p1_s_idx != -1) ? p1_s_idx - 1 : i - InpP2FractalDepth;
             p2_s = 999999;

             for(int k = start_k; k > start_k - limit && k >= InpP2FractalDepth; k--)
             {
                 if(IsFractalTrough(low, k, InpP2FractalDepth, rates_total))
                 {
                     if(low[k] < p1_s)
                     {
                         p2_s = low[k];
                         p2_s_idx = k;
                         break;
                     }
                 }
             }
             if(p2_s == 999999 && i > 0) p2_s = SecS1[i-1];
             if(p2_s == 999999) p2_s = p1_s;
         }

         SecR1[i] = p2_r;
         SecS1[i] = p2_s;
         SecP[i] = (p2_r + p2_s + close[i]) / 3.0;

         // ----------------------------------------------------
         // 3. TERTIARY P3 (Barrier 2)
         // ----------------------------------------------------
         // Must be > P2

         double p3_r = (i > 0) ? TerR1[i-1] : p2_r;
         double p3_s = (i > 0) ? TerS1[i-1] : p2_s;

         bool p3_r_broken = (close[i] > p3_r);
         bool p3_s_broken = (close[i] < p3_s);

         if(p3_r == 0 || p3_r == EMPTY_VALUE || p3_r <= p2_r || p3_r_broken)
         {
             int limit = 5000;
             int start_k = (p2_r_idx != -1) ? p2_r_idx - 1 : i - InpP3FractalDepth;
             p3_r = -1;

             for(int k = start_k; k > start_k - limit && k >= InpP3FractalDepth; k--)
             {
                 if(IsFractalPeak(high, k, InpP3FractalDepth, rates_total))
                 {
                     if(high[k] > p2_r) // Higher than P2
                     {
                         p3_r = high[k];
                         break;
                     }
                 }
             }
             if(p3_r == -1 && i > 0) p3_r = TerR1[i-1];
             if(p3_r == -1) p3_r = p2_r;
         }

         if(p3_s == 0 || p3_s == EMPTY_VALUE || p3_s >= p2_s || p3_s_broken)
         {
             int limit = 5000;
             int start_k = (p2_s_idx != -1) ? p2_s_idx - 1 : i - InpP3FractalDepth;
             p3_s = 999999;

             for(int k = start_k; k > start_k - limit && k >= InpP3FractalDepth; k--)
             {
                 if(IsFractalTrough(low, k, InpP3FractalDepth, rates_total))
                 {
                     if(low[k] < p2_s)
                     {
                         p3_s = low[k];
                         break;
                     }
                 }
             }
             if(p3_s == 999999 && i > 0) p3_s = TerS1[i-1];
             if(p3_s == 999999) p3_s = p2_s;
         }

         TerR1[i] = p3_r;
         TerS1[i] = p3_s;
         TerP[i]  = (p3_r + p3_s + close[i]) / 3.0;
      }
   }

   // --- Trends ---
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
}
