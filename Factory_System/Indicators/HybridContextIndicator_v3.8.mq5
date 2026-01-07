//+------------------------------------------------------------------+
//|                                     HybridContextIndicator_v3.8.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.8 (Active Barrier Logic - Broken Pivot Update)     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.8"

#property indicator_chart_window
// 3 Tiers * 3 Lines = 9 Buffers + 2 Trends = 11 Buffers
#property indicator_buffers 11
#property indicator_plots   11

//--- 1. PRIMARY PIVOT (Micro - Active) - DOT
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

//--- 2. SECONDARY PIVOT (Barrier 1) - DASH
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

//--- 3. TERTIARY PIVOT (Barrier 2) - DASHDOT
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
input int                InpP1Lookback         = 15;  // Primary Lookback (Bars)
input int                InpP2MinLookback      = 60;  // Secondary Min Lookback (approx 1H on M1)
input int                InpP3MinLookback      = 120; // Tertiary Min Lookback (approx 2H on M1)

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
//| Helper: Find Nearest Unbroken Barrier (Resistance)               |
//+------------------------------------------------------------------+
// Finds the nearest High in history (starting from 'min_dist' bars ago)
// that is GREATER than 'ref_price' (and greater than prev barrier if specified).
double FindResistanceBarrier(int start_bar_idx, double ref_price, int min_lookback, double floor_value = 0.0)
{
   int limit = 1000; // Search limit to prevent freezing
   double max_h = 0;

   // Start searching backwards from 'min_lookback'
   int search_start = start_bar_idx + min_lookback;

   for(int i = search_start; i < search_start + limit; i++)
   {
      if(i >= iBars(_Symbol, _Period)) break;

      double h = iHigh(_Symbol, _Period, i);

      // It must be a local peak ( Fractal-like check: i-2 < i > i+2 )
      // Simplified check for now: Is it higher than current price?
      // And is it higher than the "floor" (the previous P2 level if looking for P3)?
      if (h > ref_price && h > floor_value)
      {
         // We found a potential barrier.
         // To be a "Barrier", it should ideally be a Swing High.
         // Let's verify if it's a local maximum in its neighborhood (+- 5 bars).
         bool is_peak = true;
         for(int k=1; k<=5; k++) {
            if(iHigh(_Symbol, _Period, i+k) > h || iHigh(_Symbol, _Period, i-k) > h) {
               is_peak = false;
               break;
            }
         }

         if(is_peak) return h;
      }
   }
   return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Helper: Find Nearest Unbroken Barrier (Support)                  |
//+------------------------------------------------------------------+
double FindSupportBarrier(int start_bar_idx, double ref_price, int min_lookback, double ceiling_value = 999999.0)
{
   int limit = 1000;

   int search_start = start_bar_idx + min_lookback;

   for(int i = search_start; i < search_start + limit; i++)
   {
      if(i >= iBars(_Symbol, _Period)) break;

      double l = iLow(_Symbol, _Period, i);

      // Is it lower than current price? And lower than ceiling (previous P2)?
      if (l < ref_price && l < ceiling_value)
      {
         bool is_trough = true;
         for(int k=1; k<=5; k++) {
            if(iLow(_Symbol, _Period, i+k) < l || iLow(_Symbol, _Period, i-k) < l) {
               is_trough = false;
               break;
            }
         }

         if(is_trough) return l;
      }
   }
   return EMPTY_VALUE;
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

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.8");

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
   if(rates_total < InpP3MinLookback + 100) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         // ----------------------------------------------------
         // 1. PRIMARY P1 (Active Local High/Low)
         // ----------------------------------------------------
         // Calculates High/Low of last N bars
         double p1_h = -DBL_MAX;
         double p1_l = DBL_MAX;

         // Only look back 'InpP1Lookback' bars from 'i'
         for(int k=1; k<=InpP1Lookback; k++)
         {
            if(i-k < 0) continue;
            double h = high[i-k];
            double l = low[i-k];
            if(h > p1_h) p1_h = h;
            if(l < p1_l) p1_l = l;
         }

         // Use Close to determine Pivot P
         double P = (p1_h + p1_l + close[i]) / 3.0;
         PriP[i] = P;
         PriR1[i] = p1_h; // R1 is the local High
         PriS1[i] = p1_l; // S1 is the local Low

         // ----------------------------------------------------
         // 2. SECONDARY P2 (Barrier 1)
         // ----------------------------------------------------
         // We look for a barrier BEYOND the current P1 Range.
         // Resistance: Find a peak > p1_h, at least 'InpP2MinLookback' bars ago.
         // Support: Find a trough < p1_l, at least 'InpP2MinLookback' bars ago.

         // Note: Accessing historical data via iHigh/iLow uses bar index relative to NOW.
         // Inside the loop 'i', we need the index relative to 'i'.
         // iHigh(Symbol, Period, shift). 'shift' is relative to current time.
         // If loop is at historical bar 'i', the shift for iHigh is (rates_total - 1 - i).
         // BUT wait! OnCalculate arrays (high[], low[]) are NOT series by default (0=Oldest).
         // Let's use array access directly for speed and correctness inside loop.

         // For historical search, we need to scan BACKWARDS from 'i'.
         // Let's define specific logic:
         // If Price Breaks P2 -> Find NEW P2 (Scanning history).
         // Else -> Keep Old P2.

         double last_sec_r1 = (i > 0) ? SecR1[i-1] : EMPTY_VALUE;
         double last_sec_s1 = (i > 0) ? SecS1[i-1] : EMPTY_VALUE;

         // Check Breakout (Price > Previous Resistance)
         bool res_broken = (last_sec_r1 != EMPTY_VALUE && close[i] > last_sec_r1);
         bool sup_broken = (last_sec_s1 != EMPTY_VALUE && close[i] < last_sec_s1);

         // If broken or uninitialized, find NEW Barrier
         double new_r2 = last_sec_r1;
         double new_s2 = last_sec_s1;

         if (res_broken || last_sec_r1 == EMPTY_VALUE || last_sec_r1 == 0)
         {
             // Scan backwards from i
             // Using 'i' as anchor.
             // We need a helper that works with array indices 0..rates_total
             // Let's implement scan inline for clarity and array safety

             new_r2 = -1;
             int scan_limit = 5000;
             int start_scan = i - InpP2MinLookback;

             for(int k=start_scan; k > start_scan - scan_limit && k >= 5; k--)
             {
                 if (high[k] > close[i]) // Barrier found
                 {
                     // Verify fractal (peak)
                     if(high[k] > high[k-1] && high[k] > high[k+1] && high[k] > high[k-2] && high[k] > high[k+2])
                     {
                         new_r2 = high[k];
                         break;
                     }
                 }
             }
         }

         if (sup_broken || last_sec_s1 == EMPTY_VALUE || last_sec_s1 == 0)
         {
             new_s2 = 999999;
             int scan_limit = 5000;
             int start_scan = i - InpP2MinLookback;

             for(int k=start_scan; k > start_scan - scan_limit && k >= 5; k--)
             {
                 if (low[k] < close[i]) // Support Barrier found
                 {
                     if(low[k] < low[k-1] && low[k] < low[k+1] && low[k] < low[k-2] && low[k] < low[k+2])
                     {
                         new_s2 = low[k];
                         break;
                     }
                 }
             }
         }

         SecR1[i] = new_r2;
         SecS1[i] = new_s2;
         SecP[i]  = (new_r2 + new_s2 + close[i])/3.0; // Calc mid for P

         // ----------------------------------------------------
         // 3. TERTIARY P3 (Barrier 2)
         // ----------------------------------------------------
         // Must be beyond P2.

         double last_ter_r1 = (i > 0) ? TerR1[i-1] : EMPTY_VALUE;
         double last_ter_s1 = (i > 0) ? TerS1[i-1] : EMPTY_VALUE;

         // Breakout of P3 OR P2 pushed P3 away?
         // Logic: P3 must be > P2. If P2 moves up and passes P3, P3 must update.
         bool force_update_r3 = (last_ter_r1 != EMPTY_VALUE && new_r2 > last_ter_r1);
         bool force_update_s3 = (last_ter_s1 != EMPTY_VALUE && new_s2 < last_ter_s1);

         double new_r3 = last_ter_r1;
         double new_s3 = last_ter_s1;

         if (force_update_r3 || last_ter_r1 == EMPTY_VALUE || last_ter_r1 == 0 || close[i] > last_ter_r1)
         {
             new_r3 = -1;
             int scan_limit = 10000;
             int start_scan = i - InpP3MinLookback;

             for(int k=start_scan; k > start_scan - scan_limit && k >= 5; k--)
             {
                 // Barrier must be > P2
                 if (high[k] > new_r2)
                 {
                     if(high[k] > high[k-1] && high[k] > high[k+1])
                     {
                         new_r3 = high[k];
                         break;
                     }
                 }
             }
         }

         if (force_update_s3 || last_ter_s1 == EMPTY_VALUE || last_ter_s1 == 0 || close[i] < last_ter_s1)
         {
             new_s3 = 999999;
             int scan_limit = 10000;
             int start_scan = i - InpP3MinLookback;

             for(int k=start_scan; k > start_scan - scan_limit && k >= 5; k--)
             {
                 if (low[k] < new_s2)
                 {
                     if(low[k] < low[k-1] && low[k] < low[k+1])
                     {
                         new_s3 = low[k];
                         break;
                     }
                 }
             }
         }

         TerR1[i] = new_r3;
         TerS1[i] = new_s3;
         TerP[i]  = (new_r3 + new_s3 + close[i])/3.0;

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
