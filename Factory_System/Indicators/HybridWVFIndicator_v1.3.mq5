//+------------------------------------------------------------------+
//|                                     HybridWVFIndicator_v1.3.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.3 (Bidirectional WVF - Soft Colors)                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.3"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Up Fear (FOMO/Euphoria) - Soft Green
#property indicator_label1  "WVF Up (Euphoria)"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrForestGreen // Softer than LimeGreen
#property indicator_width1  3

//--- Plot 2: Down Fear (Panic) - Soft Red
#property indicator_label2  "WVF Down (Panic)"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_style2  STYLE_SOLID
#property indicator_color2  clrFireBrick // Softer than Red
#property indicator_width2  3

//--- Input Parameters
input group              "=== WVF Settings ==="
input int                InpPeriod             = 22;    // Lookback Period
input double             InpMultiplier         = 1.0;   // Scaling Multiplier (Default 1.0 = Percent)

//--- Buffers
double      UpBuffer[];
double      DownBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, UpBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DownBuffer, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid WVF v1.3");

   // Set levels for reference
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 20);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 30);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -20); // Downside reference

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
       // Find Highest Close and Lowest Close in Lookback Period
       double max_close = -DBL_MAX;
       double min_close = DBL_MAX;

       int search_start = MathMax(0, i - InpPeriod + 1);

       for(int j = search_start; j <= i; j++)
       {
           if(close[j] > max_close) max_close = close[j];
           if(close[j] < min_close) min_close = close[j];
       }

       // 1. Calculate Downside WVF (Panic)
       // Formula: (HighestClose - Low) / HighestClose * 100
       double down_wvf = 0.0;
       if(max_close > 0)
       {
           down_wvf = (max_close - low[i]) / max_close * 100.0 * InpMultiplier;
       }

       // 2. Calculate Upside WVF (Euphoria)
       // Formula: (High - LowestClose) / LowestClose * 100
       double up_wvf = 0.0;
       if(min_close > 0)
       {
           up_wvf = (high[i] - min_close) / min_close * 100.0 * InpMultiplier;
       }

       // Map to Buffers
       UpBuffer[i] = up_wvf;        // Positive Green Bars
       DownBuffer[i] = -down_wvf;   // Negative Red Bars
   }

   return rates_total;
}
