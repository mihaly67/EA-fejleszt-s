//+------------------------------------------------------------------+
//|                                    HybridContextIndicator_v3.13.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.13 (Option A: iCustom ZigZag Implementation)       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.13"

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

//--- 2. SECONDARY PIVOT (ZigZag Slow) - SOLID
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
double      MicroZZBuffer[]; // Stores the raw ZigZag values
double      SecZZBuffer[];

//--- Global Handles
int         micro_zz_handle = INVALID_HANDLE;
int         sec_zz_handle   = INVALID_HANDLE;
int         ema_fast_handle = INVALID_HANDLE;
int         ema_slow_handle = INVALID_HANDLE;

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

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.13");

   //--- Initialize ZigZag Handles
   // Try Examples\ZigZag first
   micro_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpMicroDepth, InpMicroDeviation, InpMicroBackstep);
   if(micro_zz_handle == INVALID_HANDLE)
   {
      micro_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpMicroDepth, InpMicroDeviation, InpMicroBackstep);
   }

   sec_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpSecDepth, InpSecDeviation, InpSecBackstep);
   if(sec_zz_handle == INVALID_HANDLE)
   {
       sec_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpSecDepth, InpSecDeviation, InpSecBackstep);
   }

   if(micro_zz_handle == INVALID_HANDLE || sec_zz_handle == INVALID_HANDLE)
   {
      Print("Critical Error: Could not load ZigZag indicator.");
      return INIT_FAILED;
   }

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

   //--- Resize internal buffers
   if(ArraySize(MicroZZBuffer) < rates_total) { ArrayResize(MicroZZBuffer, rates_total); }
   if(ArraySize(SecZZBuffer) < rates_total) { ArrayResize(SecZZBuffer, rates_total); }

   //--- Determine Start Index (Sliding Window Strategy)
   int lookback = 300;
   int start = rates_total - lookback;
   if(start < 0) start = 0;
   if (prev_calculated == 0) start = 0;

   //--- 1. Get ZigZag Data (Buffer 0 is the Line)
   // We use Buffer 0 from standard ZigZag, which usually contains the line segments.
   // Wait - checking standard "Examples/ZigZag.mq5" behavior:
   // Buffer 0 = ZigZagBuffer (DRAW_SECTION). It contains values at high/low points, and usually 0.0 or EMPTY_VALUE in between?
   // Actually DRAW_SECTION connects valid points. The buffer *between* points is typically 0.0 (or empty).
   // CopyBuffer fills the array with the values.

   int copied_m = CopyBuffer(micro_zz_handle, 0, 0, rates_total, MicroZZBuffer);
   int copied_s = CopyBuffer(sec_zz_handle, 0, 0, rates_total, SecZZBuffer);

   if(copied_m < rates_total || copied_s < rates_total) return 0; // Data not ready

   //--- 2. Connect Pivots to Form Levels (R1/S1/P)
   for(int i = start; i < rates_total; i++)
   {
      // ----------------------------------------------------
      // A) MICRO PIVOT (Fast)
      // ----------------------------------------------------
      double m_r = (i > 0) ? MicroR1[i-1] : high[i];
      double m_s = (i > 0) ? MicroS1[i-1] : low[i];
      int search_limit = 300;

      // Search Backwards for HIGH Pivot
      for(int k=i; k > i - search_limit && k >= 0; k--) {
         double zz_val = MicroZZBuffer[k];
         // Valid pivot point found?
         if(zz_val != 0 && zz_val != EMPTY_VALUE) {
             // Is this a High? Compare to High[k]
             if(MathAbs(zz_val - high[k]) < _Point) {
                 m_r = zz_val;
                 break;
             }
         }
      }

      // Search Backwards for LOW Pivot
      for(int k=i; k > i - search_limit && k >= 0; k--) {
         double zz_val = MicroZZBuffer[k];
         if(zz_val != 0 && zz_val != EMPTY_VALUE) {
             // Is this a Low? Compare to Low[k]
             if(MathAbs(zz_val - low[k]) < _Point) {
                 m_s = zz_val;
                 break;
             }
         }
      }

      MicroR1[i] = m_r;
      MicroS1[i] = m_s;
      MicroP[i]  = (m_r + m_s + close[i]) / 3.0;

      // ----------------------------------------------------
      // B) SECONDARY PIVOT (Slow)
      // ----------------------------------------------------
      double s_r = (i > 0) ? SecR1[i-1] : high[i];
      double s_s = (i > 0) ? SecS1[i-1] : low[i];

      // Search Backwards for HIGH Pivot
      for(int k=i; k > i - search_limit && k >= 0; k--) {
         double zz_val = SecZZBuffer[k];
         if(zz_val != 0 && zz_val != EMPTY_VALUE) {
             if(MathAbs(zz_val - high[k]) < _Point) {
                 s_r = zz_val;
                 break;
             }
         }
      }

      // Search Backwards for LOW Pivot
      for(int k=i; k > i - search_limit && k >= 0; k--) {
         double zz_val = SecZZBuffer[k];
         if(zz_val != 0 && zz_val != EMPTY_VALUE) {
             if(MathAbs(zz_val - low[k]) < _Point) {
                 s_s = zz_val;
                 break;
             }
         }
      }

      SecR1[i] = s_r;
      SecS1[i] = s_s;
      SecP[i]  = (s_r + s_s + close[i]) / 3.0;
   }

   //--- 3. Trends (Standard EMA)
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
   if(micro_zz_handle != INVALID_HANDLE) IndicatorRelease(micro_zz_handle);
   if(sec_zz_handle   != INVALID_HANDLE) IndicatorRelease(sec_zz_handle);

   ArrayFree(MicroZZBuffer);
   ArrayFree(SecZZBuffer);
}
