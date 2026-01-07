//+------------------------------------------------------------------+
//|                                    HybridContextIndicator_v3.15.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 3.15 (Visuals: R=Red, S=Green, No Middle Lines)      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "3.15"

#property indicator_chart_window
// 3 Tiers * 3 Lines = 9 Buffers + 2 Trends = 11 Buffers
#property indicator_buffers 11
#property indicator_plots   11

//--- 1. MICRO PIVOT (ZigZag Fast) - DOT
#property indicator_label1  "Micro Pivot P (Hidden)"
#property indicator_type1   DRAW_NONE
#property indicator_style1  STYLE_DOT
#property indicator_color1  clrNONE
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

//--- 2. SECONDARY PIVOT (ZigZag Slow) - DASHDOT
#property indicator_label4  "Secondary Pivot P (Hidden)"
#property indicator_type4   DRAW_NONE
#property indicator_style4  STYLE_DASHDOT
#property indicator_color4  clrNONE
#property indicator_width4  1

#property indicator_label5  "Secondary Pivot R1"
#property indicator_type5   DRAW_LINE
#property indicator_style5  STYLE_DASHDOT
#property indicator_color5  clrRed
#property indicator_width5  1

#property indicator_label6  "Secondary Pivot S1"
#property indicator_type6   DRAW_LINE
#property indicator_style6  STYLE_DASHDOT
#property indicator_color6  clrGreen
#property indicator_width6  1

//--- 3. TERTIARY PIVOT (ZigZag Trend) - SOLID
#property indicator_label7  "Tertiary Pivot P (Hidden)"
#property indicator_type7   DRAW_NONE
#property indicator_style7  STYLE_SOLID
#property indicator_color7  clrNONE
#property indicator_width7  1

#property indicator_label8  "Tertiary Pivot R1"
#property indicator_type8   DRAW_LINE
#property indicator_style8  STYLE_SOLID
#property indicator_color8  clrRed
#property indicator_width8  1

#property indicator_label9  "Tertiary Pivot S1"
#property indicator_type9   DRAW_LINE
#property indicator_style9  STYLE_SOLID
#property indicator_color9  clrGreen
#property indicator_width9  1

//--- 4. TRENDS
#property indicator_label10 "Trend EMA Fast"
#property indicator_type10  DRAW_LINE
#property indicator_style10 STYLE_SOLID
#property indicator_color10 clrOrange
#property indicator_width10 1

#property indicator_label11 "Trend EMA Slow"
#property indicator_type11  DRAW_LINE
#property indicator_style11 STYLE_SOLID
#property indicator_color11 clrDarkTurquoise
#property indicator_width11 1

//--- Input Parameters
input group              "=== Global Switches ==="
input bool               InpShowPivots         = true; // Master Switch: Enable/Disable All Pivots
input bool               InpShowTrends         = true; // Master Switch: Enable/Disable EMAs

input group              "=== Micro ZigZag (Fast) Settings ==="
input int                InpMicroDepth         = 5;
input int                InpMicroDeviation     = 5;
input int                InpMicroBackstep      = 3;
input ENUM_LINE_STYLE    InpMicroStyle         = STYLE_DOT;
input int                InpMicroWidth         = 1;
input color              InpMicroColorR1       = clrRed;
input color              InpMicroColorS1       = clrGreen;

input group              "=== Secondary ZigZag (Slow) Settings ==="
input int                InpSecDepth           = 30;
input int                InpSecDeviation       = 10;
input int                InpSecBackstep        = 5;
input ENUM_LINE_STYLE    InpSecStyle           = STYLE_DASHDOT;
input int                InpSecWidth           = 1;
input color              InpSecColorR1         = clrRed;
input color              InpSecColorS1         = clrGreen;

input group              "=== Tertiary ZigZag (Trend) Settings ==="
input bool               InpUseTertiary        = true; // Toggle Third Pivot
input int                InpTerDepth           = 60;
input int                InpTerDeviation       = 10;
input int                InpTerBackstep        = 5;
input ENUM_LINE_STYLE    InpTerStyle           = STYLE_SOLID;
input int                InpTerWidth           = 1;
input color              InpTerColorR1         = clrRed;
input color              InpTerColorS1         = clrGreen;

input group              "=== Trend Settings ==="
input int                InpTrendFastPeriod    = 50;
input int                InpTrendSlowPeriod    = 150;
input ENUM_MA_METHOD     InpTrendMethod        = MODE_EMA;

//--- Buffers
double      MicroP[], MicroR1[], MicroS1[];
double      SecP[], SecR1[], SecS1[];
double      TerP[], TerR1[], TerS1[];
double      TrendFast[], TrendSlow[];

//--- ZigZag Helper Buffers (Internal)
double      MicroZZBuffer[];
double      SecZZBuffer[];
double      TerZZBuffer[];

//--- Global Handles
int         micro_zz_handle = INVALID_HANDLE;
int         sec_zz_handle   = INVALID_HANDLE;
int         ter_zz_handle   = INVALID_HANDLE;
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

   // Apply Inputs
   // Micro P is Hidden (DRAW_NONE), but we can set its dummy style
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpMicroWidth);

   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpMicroColorR1);

   PlotIndexSetInteger(2, PLOT_LINE_STYLE, InpMicroStyle);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpMicroWidth);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpMicroColorS1);

   // 2. Secondary
   SetIndexBuffer(3, SecP, INDICATOR_DATA);
   SetIndexBuffer(4, SecR1, INDICATOR_DATA);
   SetIndexBuffer(5, SecS1, INDICATOR_DATA);

   PlotIndexSetInteger(3, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpSecWidth);

   PlotIndexSetInteger(4, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, InpSecColorR1);

   PlotIndexSetInteger(5, PLOT_LINE_STYLE, InpSecStyle);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, InpSecWidth);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, InpSecColorS1);

   // 3. Tertiary
   SetIndexBuffer(6, TerP, INDICATOR_DATA);
   SetIndexBuffer(7, TerR1, INDICATOR_DATA);
   SetIndexBuffer(8, TerS1, INDICATOR_DATA);

   PlotIndexSetInteger(6, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, InpTerWidth);

   PlotIndexSetInteger(7, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, InpTerColorR1);

   PlotIndexSetInteger(8, PLOT_LINE_STYLE, InpTerStyle);
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, InpTerWidth);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, InpTerColorS1);

   // 4. Trends
   SetIndexBuffer(9, TrendFast, INDICATOR_DATA);
   SetIndexBuffer(10, TrendSlow, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid Context v3.15");

   //--- Initialize ZigZag Handles (Only if Enabled)
   if(InpShowPivots)
   {
      // Micro
      micro_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpMicroDepth, InpMicroDeviation, InpMicroBackstep);
      if(micro_zz_handle == INVALID_HANDLE) micro_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpMicroDepth, InpMicroDeviation, InpMicroBackstep);

      // Secondary
      sec_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpSecDepth, InpSecDeviation, InpSecBackstep);
      if(sec_zz_handle == INVALID_HANDLE) sec_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpSecDepth, InpSecDeviation, InpSecBackstep);

      // Tertiary
      if(InpUseTertiary)
      {
         ter_zz_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpTerDepth, InpTerDeviation, InpTerBackstep);
         if(ter_zz_handle == INVALID_HANDLE) ter_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpTerDepth, InpTerDeviation, InpTerBackstep);
      }
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
   if(rates_total < InpTerDepth + 100) return 0;

   //--- PIVOT CALCULATION (Only if Enabled)
   if(InpShowPivots)
   {
      // Resize
      if(ArraySize(MicroZZBuffer) < rates_total) ArrayResize(MicroZZBuffer, rates_total);
      if(ArraySize(SecZZBuffer) < rates_total) ArrayResize(SecZZBuffer, rates_total);
      if(InpUseTertiary && ArraySize(TerZZBuffer) < rates_total) ArrayResize(TerZZBuffer, rates_total);

      // Copy Data
      if(micro_zz_handle != INVALID_HANDLE) CopyBuffer(micro_zz_handle, 0, 0, rates_total, MicroZZBuffer);
      if(sec_zz_handle != INVALID_HANDLE) CopyBuffer(sec_zz_handle, 0, 0, rates_total, SecZZBuffer);
      if(InpUseTertiary && ter_zz_handle != INVALID_HANDLE) CopyBuffer(ter_zz_handle, 0, 0, rates_total, TerZZBuffer);

      // Loop
      int lookback = 300;
      int start = rates_total - lookback;
      if(start < 0) start = 0;
      if (prev_calculated == 0) start = 0;

      for(int i = start; i < rates_total; i++)
      {
         int search_limit = 300;

         // --- MICRO ---
         if(micro_zz_handle != INVALID_HANDLE) {
             double m_r = (i > 0) ? MicroR1[i-1] : high[i];
             double m_s = (i > 0) ? MicroS1[i-1] : low[i];
             for(int k=i; k > i - search_limit && k >= 0; k--) {
                if(MicroZZBuffer[k] != 0 && MicroZZBuffer[k] != EMPTY_VALUE && MathAbs(MicroZZBuffer[k] - high[k]) < _Point) { m_r = MicroZZBuffer[k]; break; }
             }
             for(int k=i; k > i - search_limit && k >= 0; k--) {
                if(MicroZZBuffer[k] != 0 && MicroZZBuffer[k] != EMPTY_VALUE && MathAbs(MicroZZBuffer[k] - low[k]) < _Point) { m_s = MicroZZBuffer[k]; break; }
             }
             MicroR1[i] = m_r; MicroS1[i] = m_s;
             // Calculate P for completeness but it is hidden
             MicroP[i] = (m_r + m_s + close[i]) / 3.0;
         } else {
             MicroR1[i] = EMPTY_VALUE; MicroS1[i] = EMPTY_VALUE; MicroP[i] = EMPTY_VALUE;
         }

         // --- SECONDARY ---
         if(sec_zz_handle != INVALID_HANDLE) {
             double s_r = (i > 0) ? SecR1[i-1] : high[i];
             double s_s = (i > 0) ? SecS1[i-1] : low[i];
             for(int k=i; k > i - search_limit && k >= 0; k--) {
                if(SecZZBuffer[k] != 0 && SecZZBuffer[k] != EMPTY_VALUE && MathAbs(SecZZBuffer[k] - high[k]) < _Point) { s_r = SecZZBuffer[k]; break; }
             }
             for(int k=i; k > i - search_limit && k >= 0; k--) {
                if(SecZZBuffer[k] != 0 && SecZZBuffer[k] != EMPTY_VALUE && MathAbs(SecZZBuffer[k] - low[k]) < _Point) { s_s = SecZZBuffer[k]; break; }
             }
             SecR1[i] = s_r; SecS1[i] = s_s; SecP[i] = (s_r + s_s + close[i]) / 3.0;
         } else {
             SecR1[i] = EMPTY_VALUE; SecS1[i] = EMPTY_VALUE; SecP[i] = EMPTY_VALUE;
         }

         // --- TERTIARY ---
         if(InpUseTertiary && ter_zz_handle != INVALID_HANDLE) {
             double t_r = (i > 0) ? TerR1[i-1] : high[i];
             double t_s = (i > 0) ? TerS1[i-1] : low[i];
             for(int k=i; k > i - search_limit && k >= 0; k--) {
                if(TerZZBuffer[k] != 0 && TerZZBuffer[k] != EMPTY_VALUE && MathAbs(TerZZBuffer[k] - high[k]) < _Point) { t_r = TerZZBuffer[k]; break; }
             }
             for(int k=i; k > i - search_limit && k >= 0; k--) {
                if(TerZZBuffer[k] != 0 && TerZZBuffer[k] != EMPTY_VALUE && MathAbs(TerZZBuffer[k] - low[k]) < _Point) { t_s = TerZZBuffer[k]; break; }
             }
             TerR1[i] = t_r; TerS1[i] = t_s; TerP[i] = (t_r + t_s + close[i]) / 3.0;
         } else {
             TerR1[i] = EMPTY_VALUE; TerS1[i] = EMPTY_VALUE; TerP[i] = EMPTY_VALUE;
         }
      }
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
   if(ter_zz_handle   != INVALID_HANDLE) IndicatorRelease(ter_zz_handle);

   ArrayFree(MicroZZBuffer);
   ArrayFree(SecZZBuffer);
   ArrayFree(TerZZBuffer);
}
