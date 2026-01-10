//+------------------------------------------------------------------+
//|                                     HybridWVFIndicator_v1.3.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.3 (Bidirectional WVF - Normalized Fixed Scale)     |
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
input int                InpPeriod             = 22;    // Lookback Period for WVF Calculation
input int                InpNormalizationRange = 480;   // Range to find Max WVF for Scaling (Bars)

//--- Buffers
double      FearBuffer[];     // Positive (0 to 100)
double      GreedBuffer[];    // Negative (0 to -100)

//--- Internal State
double      RawFear[];        // Store raw calculated values
double      RawGreed[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, FearBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, GreedBuffer, INDICATOR_DATA);

   // Internal calculations need buffers? No, we can recalculate or use dynamic arrays.
   // But standard ZigZag/WVF doesn't need to store full history for normalization if we loop efficiently.
   // Ideally, we use INDICATOR_CALCULATIONS to store Raw values for the Max search.
   // Let's add them.

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

   // Resize Internal Arrays
   if(ArraySize(RawFear) < rates_total) {
       ArrayResize(RawFear, rates_total);
       ArrayResize(RawGreed, rates_total);
   }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;

   // 1. Calculate RAW WVF Values first
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

       // Calculate Panic (Fear) -> (HighestClose - Low) / HighestClose * 100
       double panic_val = 0.0;
       if(max_close > 0) panic_val = (max_close - low[i]) / max_close * 100.0;

       // Calculate Euphoria (Greed) -> (High - LowestClose) / LowestClose * 100
       double greed_val = 0.0;
       if(min_close > 0) greed_val = (high[i] - min_close) / min_close * 100.0;

       RawFear[i] = panic_val;
       RawGreed[i] = greed_val;
   }

   // 2. Normalize and Plot
   // We need to know the Maximum Raw WVF in the last 'InpNormalizationRange' bars to scale 0..100

   for(int i = start; i < rates_total; i++)
   {
       double local_max_fear = 0.0001; // Avoid div by zero
       double local_max_greed = 0.0001;

       int norm_start = MathMax(0, i - InpNormalizationRange + 1);

       for(int k = norm_start; k <= i; k++) {
           if(RawFear[k] > local_max_fear) local_max_fear = RawFear[k];
           if(RawGreed[k] > local_max_greed) local_max_greed = RawGreed[k];
       }

       // Normalize: (Raw / Max) * 100
       double norm_fear = (RawFear[i] / local_max_fear) * 100.0;
       double norm_greed = (RawGreed[i] / local_max_greed) * 100.0;

       // Clamp
       if(norm_fear > 100.0) norm_fear = 100.0;
       if(norm_greed > 100.0) norm_greed = 100.0;

       FearBuffer[i] = norm_fear;        // Positive
       GreedBuffer[i] = -norm_greed;     // Negative
   }

   return rates_total;
}
