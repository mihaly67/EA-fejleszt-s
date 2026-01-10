//+------------------------------------------------------------------+
//|                                     HybridWVFIndicator_v1.4.mq5 |
//|                     Copyright 2024, Gemini & User Collaboration |
//|      Verzió: 1.4 (Native Color Palette Support - Fixed Scale)     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini & User Collaboration"
#property link      "https://www.mql5.com"
#property version   "1.4"

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   1
#property indicator_minimum -100
#property indicator_maximum 100

//--- Plot 1: WVF Histogram (Color)
#property indicator_label1  "WVF Sentiment"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_style1  STYLE_SOLID
#property indicator_color1  clrForestGreen,clrFireBrick // 0=Fear(Pos), 1=Greed(Neg)
#property indicator_width1  3

//--- Input Parameters
input group              "=== WVF Settings ==="
input int                InpPeriod             = 22;    // Lookback Period
input double             InpMultiplier         = 1.0;   // Scaling Multiplier (Default 1.0 = Percent)

//--- Buffers
double      WVFBuffer[];      // Unified Buffer (Positive/Negative)
double      ColorBuffer[];    // Color Index

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, WVFBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);

   IndicatorSetString(INDICATOR_SHORTNAME, "Hybrid WVF v1.4");

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
       double panic_val = 0.0;
       if(max_close > 0)
       {
           panic_val = (max_close - low[i]) / max_close * 100.0 * InpMultiplier;
       }

       // 2. Calculate Euphoria (Greed) -> NEGATIVE
       double greed_val = 0.0;
       if(min_close > 0)
       {
           greed_val = (high[i] - min_close) / min_close * 100.0 * InpMultiplier;
       }

       // Clamp
       if(panic_val > 100.0) panic_val = 100.0;
       if(greed_val > 100.0) greed_val = 100.0;

       // Dominance Logic: Which emotion is stronger?
       if (panic_val > greed_val) {
           WVFBuffer[i] = panic_val;       // Positive (Fear)
           ColorBuffer[i] = 0.0;           // Green
       } else {
           WVFBuffer[i] = -greed_val;      // Negative (Greed)
           ColorBuffer[i] = 1.0;           // Red
       }
   }

   return rates_total;
}
