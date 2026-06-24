//+------------------------------------------------------------------+
//|                                    HybridContextIndicator_v3.10.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.10 (Dual Trend Pivot: Micro vs Secondary)          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.10"

#property indicator_chart_window
// 2 Tiers * 3 Lines = 6 Buffers + 2 Trends = 8 Buffers
#property indicator_buffers 8
#property indicator_plots   8

//--- 1. PRIMARY PIVOT (Micro Trend) - DOT
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

//--- 2. SECONDARY PIVOT (Major Trend) - SOLID
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

//--- 3. TRENDS (Optional Overlay)
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
input group              "=== Dual Pivot Settings ==="
input bool               InpShowPivots         = true;
// Micro Trend: 5-10 bars (default 5)
input int                InpMicroTrendDepth    = 5;
// Secondary Trend: 30-60 bars (default 30)
input int                InpSecondaryTrendDepth = 30;

input group              "=== Trend Settings ==="
input bool               InpShowTrends         = true;
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

//--- Buffers
double      MicroP[], MicroR1[], MicroS1[];
double      SecP[], SecR1[], SecS1[];
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
   // Check left and right neighbors within 'depth'
   for(int k=1; k<=depth; k++)
   {
      if(high[idx-k] > val || high[idx+k] >= val) return false;
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
   // 1. Micro
   SetIndexBuffer(0, MicroP, INDICATOR_DATA);
   SetIndexBuffer(1, MicroR1, INDICATOR_DATA);
   SetIndexBuffer(2, MicroS1, INDICATOR_DATA);

   // 2. Secondary
   SetIndexBuffer(3, SecP, INDICATOR_DATA);
   SetIndexBuffer(4, SecR1, INDICATOR_DATA);
   SetIndexBuffer(5, SecS1, INDICATOR_DATA);

   // 3. Trends
   SetIndexBuffer(6, TrendFast, INDICATOR_DATA);
   SetIndexBuffer(7, TrendSlow, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.10");

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
   // Ensure enough data for the largest depth
   if(rates_total < InpSecondaryTrendDepth * 2 + 100) return 0;

   // Start calculation
   // If depth is used, we need to start slightly later to avoid index out of bounds at the very beginning
   int start_offset = InpSecondaryTrendDepth + 1;
   int start = (prev_calculated > 0) ? prev_calculated - 1 : start_offset;

   if(InpShowPivots)
   {
      for(int i = start; i < rates_total; i++)
      {
         // ----------------------------------------------------
         // 1. MICRO PIVOT (Active Local Swing) - Depth ~5
         // ----------------------------------------------------
         // We look for the most recent completed Micro Fractal relative to 'i'.

         double m_r = (i > 0) ? MicroR1[i-1] : high[i];
         double m_s = (i > 0) ? MicroS1[i-1] : low[i];

         // Search backwards for the newest Micro Peak
         int scan_limit_m = 500;
         int scan_start = i - InpMicroTrendDepth; // Completed fractal is at i-Depth

         for(int k = scan_start; k > scan_start - scan_limit_m && k >= InpMicroTrendDepth; k--)
         {
            if(IsFractalPeak(high, k, InpMicroTrendDepth, rates_total))
            {
               m_r = high[k];
               break; // Found the most recent one
            }
         }

         // Search backwards for the newest Micro Trough
         for(int k = scan_start; k > scan_start - scan_limit_m && k >= InpMicroTrendDepth; k--)
         {
            if(IsFractalTrough(low, k, InpMicroTrendDepth, rates_total))
            {
               m_s = low[k];
               break;
            }
         }

         MicroR1[i] = m_r;
         MicroS1[i] = m_s;
         MicroP[i]  = (m_r + m_s + close[i]) / 3.0;

         // ----------------------------------------------------
         // 2. SECONDARY PIVOT (Major Barrier) - Depth ~30
         // ----------------------------------------------------
         // This acts as a Support/Resistance Barrier.
         // It should persist until broken.
         // If broken, we scan history for the NEXT valid Secondary Pivot.

         double s_r = (i > 0) ? SecR1[i-1] : m_r;
         double s_s = (i > 0) ? SecS1[i-1] : m_s;

         bool r_broken = (close[i] > s_r);
         bool s_broken = (close[i] < s_s);

         // Logic:
         // If price > Current Secondary Resistance -> Find a higher Secondary Peak in history.
         // If price < Current Secondary Support -> Find a lower Secondary Trough in history.
         // Also initialized if empty.

         if(s_r == 0 || s_r == EMPTY_VALUE || s_r <= m_r || r_broken)
         {
             // Scan for new Resistance Barrier
             int limit = 5000;
             // Scan starts from where?
             // We need a Secondary Fractal (Depth 30) that is HIGHER than current Micro Resistance (or current price).
             // Ideally, we scan backwards from 'i'

             s_r = -1;
             int s_start = i - InpSecondaryTrendDepth;

             for(int k = s_start; k > s_start - limit && k >= InpSecondaryTrendDepth; k--)
             {
                 if(IsFractalPeak(high, k, InpSecondaryTrendDepth, rates_total))
                 {
                     // Barrier condition: Must be higher than the Micro Resistance (or the broken level)
                     // Using current Close[i] as the floor is safest for "Barrier ahead".
                     if(high[k] > close[i])
                     {
                         s_r = high[k];
                         break;
                     }
                 }
             }

             // Fallback: if no historical barrier found (ATH), keep old or use current High
             if(s_r == -1 && i > 0) s_r = SecR1[i-1];
             if(s_r == -1) s_r = high[i] * 1.01; // Temporary visual fallback
         }

         if(s_s == 0 || s_s == EMPTY_VALUE || s_s >= m_s || s_broken)
         {
             int limit = 5000;
             int s_start = i - InpSecondaryTrendDepth;
             s_s = 999999;

             for(int k = s_start; k > s_start - limit && k >= InpSecondaryTrendDepth; k--)
             {
                 if(IsFractalTrough(low, k, InpSecondaryTrendDepth, rates_total))
                 {
                     // Barrier condition: Must be lower than current Price
                     if(low[k] < close[i])
                     {
                         s_s = low[k];
                         break;
                     }
                 }
             }

             if(s_s == 999999 && i > 0) s_s = SecS1[i-1];
             if(s_s == 999999) s_s = low[i] * 0.99;
         }

         SecR1[i] = s_r;
         SecS1[i] = s_s;
         SecP[i]  = (s_r + s_s + close[i]) / 3.0;
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
