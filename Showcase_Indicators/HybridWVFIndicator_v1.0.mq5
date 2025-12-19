//+------------------------------------------------------------------+
//|                                     HybridWVFIndicator_v1.0.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.0 (Williams Vix Fix - Synthetic Fear)              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.0"

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1

//--- Plot 1: WVF Histogram
#property indicator_label1  "WVF Fear"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrGray, clrOrangeRed, clrRed
#property indicator_width1  3

//--- Input Parameters
input group              "=== WVF Settings ==="
input int                InpPeriod             = 22;    // Lookback Period (Standard 22)
input double             InpHighLevel          = 2.0;   // High Stress Level (Visual)
input double             InpExtremeLevel       = 5.0;   // Extreme Stress Level (Visual)

//--- Buffers
double      WVFBuffer[];
double      ColorBuffer[];
double      HighsBuffer[]; // Temp buffer for highest close

//--- Handles
// None needed, pure price math

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, WVFBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, HighsBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid WVF v1.0");

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
   if(rates_total < InpPeriod) return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
       // 1. Find Highest Close in last N bars
       double max_close = 0;
       int search_start = MathMax(0, i - InpPeriod + 1);

       for(int j = search_start; j <= i; j++)
       {
           if(close[j] > max_close) max_close = close[j];
       }

       // 2. Calculate WVF
       // Formula: (HighestClose - Low) / HighestClose * 100
       // Note: "Low" is the current bar's Low.

       double wvf = 0.0;
       if(max_close > 0)
       {
           wvf = (max_close - low[i]) / max_close * 100.0;
       }

       WVFBuffer[i] = wvf;

       // 3. Color Logic
       if(wvf > InpExtremeLevel) ColorBuffer[i] = 2; // Red (Extreme Fear)
       else if(wvf > InpHighLevel) ColorBuffer[i] = 1; // Orange (High Fear)
       else ColorBuffer[i] = 0; // Gray (Normal)
   }

   return rates_total;
}
