//+------------------------------------------------------------------+
//|                                     HybridWVFIndicator_v1.3.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.3 (Bidirectional WVF - Fixed Scale)                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.3"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_minimum -100
#property indicator_maximum 100

//--- Plot 1: Fear/Panic (Market Bottoms) -> Positive -> Green (Buy Opp)
#property indicator_label1  "WVF Fear (Panic)"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrForestGreen // Fear = Opportunity
#property indicator_width1  3

//--- Plot 2: Euphoria/Greed (Market Tops) -> Negative -> Red (Sell Danger)
#property indicator_label2  "WVF Euphoria (Greed)"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_style2  STYLE_SOLID
#property indicator_color2  clrFireBrick // Greed = Danger
#property indicator_width2  3

//--- Input Parameters
input group              "=== WVF Settings ==="
input int                InpPeriod             = 22;    // Lookback Period
input double             InpMultiplier         = 1.0;   // Scaling Multiplier (Default 1.0 = Percent)

//--- Buffers
double      FearBuffer[];     // Positive (0 to 100)
double      GreedBuffer[];    // Negative (0 to -100)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, FearBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, GreedBuffer, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid WVF v1.3");

   // Set Levels: 0, +/- 20, +/- 30
   IndicatorSetInteger(INDICATOR_LEVELS, 5);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 20.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 30.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, -20.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 4, -30.0);

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

       // 1. Calculate Panic (Fear) -> POSITIVE
       // Standard WVF Formula: (HighestClose - Low) / HighestClose * 100
       double panic_val = 0.0;
       if(max_close > 0)
       {
           panic_val = (max_close - low[i]) / max_close * 100.0 * InpMultiplier;
       }

       // 2. Calculate Euphoria (Greed) -> NEGATIVE
       // Inverse Formula: (High - LowestClose) / LowestClose * 100
       double greed_val = 0.0;
       if(min_close > 0)
       {
           greed_val = (high[i] - min_close) / min_close * 100.0 * InpMultiplier;
       }

       // Clamp to 100/-100 visual range
       if(panic_val > 100.0) panic_val = 100.0;
       if(greed_val > 100.0) greed_val = 100.0;

       // Map to Buffers
       FearBuffer[i] = panic_val;        // Positive (Green)
       GreedBuffer[i] = -greed_val;      // Negative (Red)
   }

   return rates_total;
}
